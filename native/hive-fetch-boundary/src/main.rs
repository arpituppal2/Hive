use std::collections::{HashMap, HashSet};
use std::io::{self, BufRead, BufReader, BufWriter, Write};
use std::process::ExitCode;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use hive_fetch_boundary::{
    protocol::{
        encode_body, read_request, write_response, CodecConfig, ProtocolError, WorkerErrorCode,
        WorkerRequest, WorkerResponse, PROTOCOL_VERSION,
    },
    ResearchFetchError, ResearchFetcher, ResearchFetcherConfig,
};

const WORKER_USER_AGENT: &str = "HiveResearchWorker/0.1";
const MAX_ACTIVE_JOBS: usize = 8;

type Output = Arc<Mutex<BufWriter<Box<dyn Write + Send>>>>;
type CancellationRegistry = Arc<Mutex<HashMap<String, Arc<AtomicBool>>>>;
type FetchRunner = Arc<
    dyn Fn(&str, u64, usize) -> Result<hive_fetch_boundary::ResearchFetchResult, ResearchFetchError>
        + Send
        + Sync,
>;

struct Worker {
    config: CodecConfig,
    output: Output,
    active: CancellationRegistry,
    /// Request IDs are unique across the entire worker session. A Cancel
    /// references an existing fetch ID and is not inserted into this set.
    seen_request_ids: HashSet<String>,
    jobs: Vec<JoinHandle<()>>,
    fetch_runner: FetchRunner,
}

impl Worker {
    fn new<W: Write + Send + 'static>(
        writer: W,
        config: CodecConfig,
    ) -> Result<Self, ProtocolError> {
        config.validate()?;
        Ok(Self {
            config,
            output: Arc::new(Mutex::new(BufWriter::new(Box::new(writer)))),
            active: Arc::new(Mutex::new(HashMap::new())),
            seen_request_ids: HashSet::new(),
            jobs: Vec::new(),
            fetch_runner: Arc::new(perform_fetch),
        })
    }

    #[cfg(test)]
    fn with_fetch_runner<W: Write + Send + 'static>(
        writer: W,
        config: CodecConfig,
        fetch_runner: FetchRunner,
    ) -> Result<Self, ProtocolError> {
        let mut worker = Self::new(writer, config)?;
        worker.fetch_runner = fetch_runner;
        Ok(worker)
    }

    fn emit(&self, response: WorkerResponse) {
        let result = self
            .output
            .lock()
            .map_err(|_| io::Error::new(io::ErrorKind::Other, "worker output lock poisoned"))
            .and_then(|mut writer| {
                write_response(&mut *writer, &response, self.config).map_err(protocol_io)
            });
        if let Err(error) = result {
            eprintln!("hive-fetch-worker: failed to write response: {error}");
        }
    }

    fn run<R: BufRead>(&mut self, reader: &mut R) -> Result<(), ProtocolError> {
        self.emit(WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        });

        loop {
            let request = match read_request(reader, self.config) {
                Ok(Some(request)) => request,
                Ok(None) => {
                    self.cancel_all();
                    break;
                }
                Err(error) => {
                    self.emit(WorkerResponse::Error {
                        request_id: None,
                        code: error_code(&error),
                        message: safe_message(error.to_string()),
                    });
                    self.cancel_all();
                    return Err(error);
                }
            };

            self.reap_finished();
            match request {
                WorkerRequest::Fetch {
                    request_id,
                    url,
                    timeout_ms,
                    max_bytes,
                    ..
                } => self.start_fetch(request_id, url, timeout_ms, max_bytes),
                WorkerRequest::Cancel { request_id, .. } => self.cancel(request_id),
                WorkerRequest::Ping { request_id, .. } => {
                    if self.seen_request_ids.insert(request_id.clone()) {
                        self.emit(WorkerResponse::Pong { request_id });
                    } else {
                        self.emit(WorkerResponse::Error {
                            request_id: Some(request_id),
                            code: WorkerErrorCode::InvalidRequest,
                            message: "request_id has already been used in this worker session"
                                .to_owned(),
                        });
                    }
                }
                WorkerRequest::Shutdown { .. } => {
                    self.cancel_all();
                    self.wait_for_jobs();
                    self.emit(WorkerResponse::ShutdownAck);
                    break;
                }
            }
        }
        self.wait_for_jobs();
        Ok(())
    }

    fn start_fetch(&mut self, request_id: String, url: String, timeout_ms: u64, max_bytes: usize) {
        if !self.seen_request_ids.insert(request_id.clone()) {
            self.emit(WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::InvalidRequest,
                message: "request_id has already been used in this worker session".to_owned(),
            });
            return;
        }
        if self
            .active
            .lock()
            .map(|active| active.len())
            .unwrap_or(MAX_ACTIVE_JOBS)
            >= MAX_ACTIVE_JOBS
        {
            self.emit(WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::InvalidRequest,
                message: "worker concurrency limit reached".to_owned(),
            });
            return;
        }

        let cancellation = Arc::new(AtomicBool::new(false));
        let inserted = self
            .active
            .lock()
            .map(|mut active| {
                active
                    .insert(request_id.clone(), cancellation.clone())
                    .is_none()
            })
            .unwrap_or(false);
        if !inserted {
            self.emit(WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::InvalidRequest,
                message: "request_id is already active".to_owned(),
            });
            return;
        }

        self.emit(WorkerResponse::FetchStarted {
            request_id: request_id.clone(),
        });
        let output = Arc::clone(&self.output);
        let active = Arc::clone(&self.active);
        let fetch_runner = Arc::clone(&self.fetch_runner);
        let config = self.config;
        self.jobs.push(thread::spawn(move || {
            let result = fetch_runner(&url, timeout_ms, max_bytes);
            let was_cancelled = cancellation.load(Ordering::Acquire);
            if let Ok(mut active) = active.lock() {
                active.remove(&request_id);
            }
            let response = if was_cancelled {
                WorkerResponse::Cancelled { request_id }
            } else {
                match result {
                    Ok(result) => WorkerResponse::FetchCompleted {
                        request_id,
                        status: result.status,
                        final_url: result.final_url.to_string(),
                        content_type: result.content_type,
                        body_base64: encode_body(&result.body),
                        redirect_count: result.redirect_count,
                    },
                    Err(error) => WorkerResponse::Error {
                        request_id: Some(request_id),
                        code: WorkerErrorCode::FetchFailed,
                        message: safe_fetch_error(error),
                    },
                }
            };
            if let Ok(mut writer) = output.lock() {
                if let Err(error) = write_response(&mut *writer, &response, config) {
                    eprintln!("hive-fetch-worker: failed to write fetch response: {error}");
                }
            } else {
                eprintln!("hive-fetch-worker: output lock poisoned");
            }
        }));
    }

    fn cancel(&self, request_id: String) {
        let found = self
            .active
            .lock()
            .ok()
            .and_then(|active| active.get(&request_id).cloned());
        match found {
            Some(flag) => flag.store(true, Ordering::Release),
            None => self.emit(WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::NotFound,
                message: "request_id is not active".to_owned(),
            }),
        }
    }

    fn cancel_all(&self) {
        if let Ok(active) = self.active.lock() {
            for flag in active.values() {
                flag.store(true, Ordering::Release);
            }
        }
    }

    fn reap_finished(&mut self) {
        let mut remaining = Vec::with_capacity(self.jobs.len());
        for job in self.jobs.drain(..) {
            if job.is_finished() {
                if let Err(error) = job.join() {
                    eprintln!("hive-fetch-worker: fetch thread panicked: {error:?}");
                }
            } else {
                remaining.push(job);
            }
        }
        self.jobs = remaining;
    }

    fn wait_for_jobs(&mut self) {
        while let Some(job) = self.jobs.pop() {
            if let Err(error) = job.join() {
                eprintln!("hive-fetch-worker: fetch thread panicked: {error:?}");
            }
        }
    }
}

fn perform_fetch(
    url: &str,
    timeout_ms: u64,
    max_bytes: usize,
) -> Result<hive_fetch_boundary::ResearchFetchResult, ResearchFetchError> {
    let fetcher = ResearchFetcher::new(ResearchFetcherConfig {
        max_redirects: 5,
        max_bytes,
        timeout: Duration::from_millis(timeout_ms),
        user_agent: WORKER_USER_AGENT.to_owned(),
    })?;
    fetcher.fetch(url)
}

fn protocol_io(error: ProtocolError) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, error.to_string())
}

fn error_code(error: &ProtocolError) -> WorkerErrorCode {
    match error {
        ProtocolError::FrameTooLarge { .. } => WorkerErrorCode::FrameTooLarge,
        ProtocolError::MalformedJson(_)
        | ProtocolError::MissingDelimiter
        | ProtocolError::EmptyFrame => WorkerErrorCode::MalformedFrame,
        ProtocolError::InvalidRequest(message) if message.contains("version") => {
            WorkerErrorCode::UnsupportedProtocol
        }
        ProtocolError::InvalidRequest(_) => WorkerErrorCode::InvalidRequest,
        ProtocolError::Io(_) | ProtocolError::Serialization(_) => WorkerErrorCode::Internal,
    }
}

fn safe_message(message: String) -> String {
    let mut message: String = message
        .chars()
        .filter(|character| !character.is_control())
        .collect();
    if message.is_empty() {
        message.push_str("worker error");
    }
    truncate_utf8_bytes(message, hive_fetch_boundary::protocol::MAX_MESSAGE_BYTES)
}

fn truncate_utf8_bytes(mut value: String, limit: usize) -> String {
    if value.len() <= limit {
        return value;
    }
    let mut end = limit;
    while !value.is_char_boundary(end) {
        end -= 1;
    }
    value.truncate(end);
    value
}

fn safe_fetch_error(error: ResearchFetchError) -> String {
    let category = match error {
        ResearchFetchError::InvalidUrl(_) => "invalid research URL",
        ResearchFetchError::InvalidTimeout => "invalid research timeout",
        ResearchFetchError::UnsupportedScheme(_) => "unsupported research scheme",
        ResearchFetchError::MissingHost => "research URL has no host",
        ResearchFetchError::RedirectLimit => "research redirect limit exceeded",
        ResearchFetchError::RedirectMissingLocation => "research redirect has no Location",
        ResearchFetchError::ResponseTooLarge(_) => "research response exceeded the size limit",
        ResearchFetchError::RedirectDowngrade => "HTTPS downgrade redirect blocked",
        ResearchFetchError::InformationalResponse(_) => "informational HTTP response rejected",
        ResearchFetchError::InvalidRequestHeader => "invalid research request header",
        ResearchFetchError::ConflictingContentLength => "conflicting Content-Length",
        ResearchFetchError::AmbiguousTransferEncoding => "ambiguous Transfer-Encoding",
        ResearchFetchError::MalformedResponse(_) => "malformed research response",
        ResearchFetchError::Io(_) => "research network I/O failed",
        ResearchFetchError::Tls(_) => "research TLS failed",
        ResearchFetchError::Resolve(_) => "research hostname resolution failed",
    };
    category.to_owned()
}

fn main() -> ExitCode {
    let stdin = io::stdin();
    let mut reader = BufReader::new(stdin.lock());
    let stdout = io::stdout();
    let writer = stdout;
    let mut worker = match Worker::new(writer, CodecConfig::default()) {
        Ok(worker) => worker,
        Err(error) => {
            eprintln!("hive-fetch-worker: failed to initialize: {error}");
            return ExitCode::FAILURE;
        }
    };

    match worker.run(&mut reader) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("hive-fetch-worker: protocol stopped: {error}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;
    use std::sync::{mpsc, Mutex};

    #[test]
    fn ping_and_shutdown_are_served_without_network() {
        let requests = format!(
            "{{\"type\":\"ping\",\"protocol_version\":1,\"request_id\":\"ping-1\"}}\n{{\"type\":\"shutdown\",\"protocol_version\":1}}\n"
        );
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let sink = SharedVecWriter(Arc::clone(&output));
        let mut worker = Worker::new(
            sink,
            CodecConfig {
                max_frame_bytes: 4096,
            },
        )
        .unwrap();
        worker
            .run(&mut BufReader::new(Cursor::new(requests.into_bytes())))
            .unwrap();
        let bytes = output.lock().unwrap().clone();
        let text = String::from_utf8(bytes).unwrap();
        assert!(text.contains("\"type\":\"ready\""));
        assert!(text.contains("\"type\":\"pong\""));
        assert!(text.contains("\"type\":\"shutdown_ack\""));
    }

    #[test]
    fn request_ids_cannot_cross_fetch_and_control_namespaces() {
        let requests = b"{\"type\":\"ping\",\"protocol_version\":1,\"request_id\":\"shared\"}\n{\"type\":\"fetch\",\"protocol_version\":1,\"request_id\":\"shared\",\"url\":\"https://example.com\",\"timeout_ms\":1,\"max_bytes\":1}\n{\"type\":\"shutdown\",\"protocol_version\":1}\n";
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let sink = SharedVecWriter(Arc::clone(&output));
        let mut worker = Worker::new(
            sink,
            CodecConfig {
                max_frame_bytes: 4096,
            },
        )
        .unwrap();
        worker
            .run(&mut BufReader::new(Cursor::new(requests)))
            .unwrap();
        let text = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert!(text.contains("request_id has already been used in this worker session"));
        assert!(!text.contains("fetch_started"));
    }

    #[test]
    fn safe_message_is_control_free_and_utf8_byte_bounded() {
        let message = safe_message(format!("\u{0000}{}", "界".repeat(10_000)));
        assert!(!message.chars().any(char::is_control));
        assert!(message.len() <= hive_fetch_boundary::protocol::MAX_MESSAGE_BYTES);
        assert!(message.is_char_boundary(message.len()));
    }

    #[test]
    fn cancellation_wins_before_runner_completion() {
        let (started_tx, started_rx) = mpsc::channel();
        let (release_tx, release_rx) = mpsc::channel();
        let release_rx = Arc::new(Mutex::new(release_rx));
        let runner_release = Arc::clone(&release_rx);
        let runner: FetchRunner = Arc::new(move |_, _, _| {
            started_tx.send(()).expect("test runner start receiver");
            runner_release
                .lock()
                .expect("test runner release lock")
                .recv()
                .expect("test runner release token");
            Err(ResearchFetchError::UnsupportedScheme("test".to_owned()))
        });
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let sink = SharedVecWriter(Arc::clone(&output));
        let mut worker = Worker::with_fetch_runner(
            sink,
            CodecConfig {
                max_frame_bytes: 4096,
            },
            runner,
        )
        .unwrap();

        worker.start_fetch("cancel-me".to_owned(), "test://blocked".to_owned(), 1, 1);
        started_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("runner should start before cancellation");
        worker.cancel("cancel-me".to_owned());
        release_tx.send(()).expect("release cancelled runner");
        worker.wait_for_jobs();

        let text = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert!(text.contains("fetch_started"));
        assert!(text.contains("cancelled"));
        assert!(!text.contains("fetch_failed"));
    }

    #[test]
    fn active_job_cap_rejects_the_ninth_job_without_networking() {
        let (started_tx, started_rx) = mpsc::channel();
        let (release_tx, release_rx) = mpsc::channel();
        let release_rx = Arc::new(Mutex::new(release_rx));
        let runner_release = Arc::clone(&release_rx);
        let runner: FetchRunner = Arc::new(move |_, _, _| {
            started_tx.send(()).expect("test runner start receiver");
            runner_release
                .lock()
                .expect("test runner release lock")
                .recv()
                .expect("test runner release token");
            Err(ResearchFetchError::UnsupportedScheme("test".to_owned()))
        });
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let sink = SharedVecWriter(Arc::clone(&output));
        let mut worker = Worker::with_fetch_runner(
            sink,
            CodecConfig {
                max_frame_bytes: 4096,
            },
            runner,
        )
        .unwrap();

        for index in 0..MAX_ACTIVE_JOBS {
            worker.start_fetch(format!("job-{index}"), "test://blocked".to_owned(), 1, 1);
        }
        for _ in 0..MAX_ACTIVE_JOBS {
            started_rx
                .recv_timeout(Duration::from_secs(1))
                .expect("all capped runners should start");
        }
        worker.start_fetch("job-over-cap".to_owned(), "test://blocked".to_owned(), 1, 1);
        let text_before_release = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert!(text_before_release.contains("concurrency limit reached"));

        for _ in 0..MAX_ACTIVE_JOBS {
            release_tx.send(()).expect("release capped runner");
        }
        worker.wait_for_jobs();
        let text = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert_eq!(text.matches("fetch_started").count(), MAX_ACTIVE_JOBS);
    }

    #[test]
    fn shutdown_ack_waits_for_active_runner_to_stop() {
        let (started_tx, started_rx) = mpsc::channel();
        let (release_tx, release_rx) = mpsc::channel();
        let release_rx = Arc::new(Mutex::new(release_rx));
        let runner_release = Arc::clone(&release_rx);
        let release_guard = ReleaseGuard::new(release_tx.clone());
        let runner: FetchRunner = Arc::new(move |_, _, _| {
            started_tx.send(()).expect("shutdown test start receiver");
            runner_release
                .lock()
                .expect("shutdown test release lock")
                .recv()
                .expect("shutdown test release token");
            Err(ResearchFetchError::UnsupportedScheme("test".to_owned()))
        });
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let worker_output = Arc::clone(&output);
        let mut worker = Worker::with_fetch_runner(
            SharedVecWriter(Arc::clone(&output)),
            CodecConfig {
                max_frame_bytes: 4096,
            },
            runner,
        )
        .unwrap();
        let requests = b"{\"type\":\"fetch\",\"protocol_version\":1,\"request_id\":\"shutdown-fetch\",\"url\":\"test://blocked\",\"timeout_ms\":1,\"max_bytes\":1}\n{\"type\":\"shutdown\",\"protocol_version\":1}\n".to_vec();
        let run_thread = thread::spawn(move || {
            let mut reader = BufReader::new(Cursor::new(requests));
            worker.run(&mut reader)
        });

        started_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("active runner should start before shutdown waits");
        let before_release = String::from_utf8(worker_output.lock().unwrap().clone()).unwrap();
        assert!(before_release.contains("fetch_started"));
        assert!(!before_release.contains("shutdown_ack"));
        release_guard.release();
        run_thread
            .join()
            .expect("shutdown worker thread")
            .expect("shutdown worker should complete successfully");
        let after_release = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert!(after_release.contains("cancelled"));
        assert!(after_release.contains("shutdown_ack"));
    }

    #[test]
    fn unknown_cancel_returns_not_found() {
        let requests = b"{\"type\":\"cancel\",\"protocol_version\":1,\"request_id\":\"missing\"}\n{\"type\":\"shutdown\",\"protocol_version\":1}\n";
        let output = Arc::new(Mutex::new(Vec::<u8>::new()));
        let sink = SharedVecWriter(Arc::clone(&output));
        let mut worker = Worker::new(
            sink,
            CodecConfig {
                max_frame_bytes: 4096,
            },
        )
        .unwrap();
        worker
            .run(&mut BufReader::new(Cursor::new(requests)))
            .unwrap();
        let text = String::from_utf8(output.lock().unwrap().clone()).unwrap();
        assert!(text.contains("\"code\":\"not_found\""));
    }

    struct ReleaseGuard(Option<mpsc::Sender<()>>);

    impl ReleaseGuard {
        fn new(sender: mpsc::Sender<()>) -> Self {
            Self(Some(sender))
        }

        fn release(mut self) {
            if let Some(sender) = self.0.take() {
                let _ = sender.send(());
            }
        }
    }

    impl Drop for ReleaseGuard {
        fn drop(&mut self) {
            if let Some(sender) = self.0.take() {
                let _ = sender.send(());
            }
        }
    }

    struct SharedVecWriter(Arc<Mutex<Vec<u8>>>);

    impl Write for SharedVecWriter {
        fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
            self.0.lock().unwrap().extend_from_slice(bytes);
            Ok(bytes.len())
        }

        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
}
