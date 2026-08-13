use std::io::{self, BufReader, Read, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use hive_fetch_boundary::protocol::{
    read_response_into_session, ProtocolSession, WorkerErrorCode, WorkerRequest, WorkerResponse,
    PROTOCOL_VERSION,
};

const IO_TIMEOUT: Duration = Duration::from_secs(3);
const POLL_INTERVAL: Duration = Duration::from_millis(10);
type ResponseMessage = Result<WorkerResponse, String>;

struct WorkerProcess {
    child: Child,
    stdin: Option<ChildStdin>,
    responses: Receiver<ResponseMessage>,
    response_thread: Option<JoinHandle<()>>,
    stderr: Option<(Receiver<String>, JoinHandle<()>)>,
}

impl WorkerProcess {
    fn spawn() -> io::Result<Self> {
        let binary = worker_binary_path()?;
        let mut child = Command::new(binary)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;
        let stdin = child.stdin.take().expect("piped worker stdin");
        let stdout = child.stdout.take().expect("piped worker stdout");
        let stderr = child.stderr.take().expect("piped worker stderr");

        let (response_sender, response_receiver) = mpsc::channel();
        let response_thread = thread::spawn(move || read_responses(stdout, response_sender));

        let (stderr_sender, stderr_receiver) = mpsc::channel();
        let stderr_thread = thread::spawn(move || {
            let mut reader = BufReader::new(stderr);
            let mut output = String::new();
            let _ = reader.read_to_string(&mut output);
            let _ = stderr_sender.send(output);
        });

        Ok(Self {
            child,
            stdin: Some(stdin),
            responses: response_receiver,
            response_thread: Some(response_thread),
            stderr: Some((stderr_receiver, stderr_thread)),
        })
    }

    fn send(&mut self, request: &WorkerRequest) -> io::Result<()> {
        let stdin = self.stdin.as_mut().expect("worker stdin is open");
        serde_json::to_writer(&mut *stdin, request)
            .map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))?;
        stdin.write_all(b"\n")?;
        stdin.flush()
    }

    fn close_stdin(&mut self) {
        self.stdin.take();
    }

    fn read_response(&self) -> io::Result<WorkerResponse> {
        match self.responses.recv_timeout(IO_TIMEOUT) {
            Ok(Ok(response)) => Ok(response),
            Ok(Err(error)) => Err(io::Error::new(io::ErrorKind::InvalidData, error)),
            Err(error) => Err(io::Error::new(
                io::ErrorKind::TimedOut,
                format!("worker response timed out: {error}"),
            )),
        }
    }

    fn finish(mut self) -> io::Result<(bool, String)> {
        self.close_stdin();
        let status = wait_for_child(&mut self.child, IO_TIMEOUT)?;
        let stderr = self.take_stderr()?;
        self.join_response_thread()?;
        Ok((status.success(), stderr))
    }

    fn take_stderr(&mut self) -> io::Result<String> {
        let (receiver, thread) = self.stderr.take().expect("stderr drain is still available");
        let output = receiver.recv_timeout(IO_TIMEOUT).map_err(|error| {
            io::Error::new(
                io::ErrorKind::TimedOut,
                format!("stderr drain timed out: {error}"),
            )
        })?;
        thread
            .join()
            .map_err(|_| io::Error::new(io::ErrorKind::Other, "stderr drain thread panicked"))?;
        Ok(output)
    }

    fn join_response_thread(&mut self) -> io::Result<()> {
        if let Some(thread) = self.response_thread.take() {
            thread
                .join()
                .map_err(|_| io::Error::new(io::ErrorKind::Other, "response thread panicked"))?;
        }
        Ok(())
    }
}

impl Drop for WorkerProcess {
    fn drop(&mut self) {
        self.stdin.take();
        if self.child.try_wait().ok().flatten().is_none() {
            let _ = self.child.kill();
            let _ = self.child.wait();
        }
        if let Some(thread) = self.response_thread.take() {
            let _ = thread.join();
        }
        if let Some((_, thread)) = self.stderr.take() {
            let _ = thread.join();
        }
    }
}

fn worker_binary_path() -> io::Result<PathBuf> {
    if let Some(path) = std::env::var_os("CARGO_BIN_EXE_hive_fetch_worker") {
        return Ok(PathBuf::from(path));
    }

    // Cargo does not export CARGO_BIN_EXE_* for every explicit target/profile
    // combination. Integration tests themselves live in target/<profile>/deps,
    // so the sibling binary path is stable without assuming the repository
    // root or a platform-specific target directory.
    let test_binary = std::env::current_exe()?;
    let profile_dir = test_binary
        .parent()
        .and_then(|deps| deps.parent())
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "test profile directory missing"))?;
    let worker_name = format!("hive-fetch-worker{}", std::env::consts::EXE_SUFFIX);
    let worker = profile_dir.join(worker_name);
    if worker.is_file() {
        Ok(worker)
    } else {
        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("worker binary not found at {}", worker.display()),
        ))
    }
}

fn read_responses(stdout: ChildStdout, sender: mpsc::Sender<ResponseMessage>) {
    let mut reader = BufReader::new(stdout);
    let mut session = ProtocolSession::new();
    loop {
        match read_response_into_session(&mut reader, Default::default(), &mut session) {
            Ok(Some(response)) => {
                if sender.send(Ok(response)).is_err() {
                    break;
                }
            }
            Ok(None) => break,
            Err(error) => {
                let _ = sender.send(Err(error.to_string()));
                break;
            }
        }
    }
}

fn wait_for_child(child: &mut Child, timeout: Duration) -> io::Result<std::process::ExitStatus> {
    let deadline = Instant::now() + timeout;
    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(status);
        }
        if Instant::now() >= deadline {
            let _ = child.kill();
            return child.wait();
        }
        thread::sleep(POLL_INTERVAL);
    }
}

fn ping(request_id: &str) -> WorkerRequest {
    WorkerRequest::Ping {
        protocol_version: PROTOCOL_VERSION,
        request_id: request_id.to_owned(),
    }
}

fn shutdown() -> WorkerRequest {
    WorkerRequest::Shutdown {
        protocol_version: PROTOCOL_VERSION,
    }
}

#[test]
fn compiled_worker_completes_ready_ping_and_shutdown_handshake() {
    let mut worker = WorkerProcess::spawn().expect("spawn worker");

    assert_eq!(
        worker.read_response().expect("ready response"),
        WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        }
    );
    worker.send(&ping("ping-1")).expect("send ping");
    assert_eq!(
        worker.read_response().expect("pong response"),
        WorkerResponse::Pong {
            request_id: "ping-1".to_owned(),
        }
    );
    worker.send(&shutdown()).expect("send shutdown");
    assert_eq!(
        worker.read_response().expect("shutdown response"),
        WorkerResponse::ShutdownAck
    );

    let (success, stderr) = worker.finish().expect("reap worker");
    assert!(success, "worker exited unsuccessfully: {stderr}");
    assert!(stderr.is_empty(), "unexpected worker diagnostics: {stderr}");
}

#[test]
fn compiled_worker_rejects_cross_kind_request_id_reuse_without_networking() {
    let mut worker = WorkerProcess::spawn().expect("spawn worker");
    assert!(matches!(
        worker.read_response().expect("ready response"),
        WorkerResponse::Ready { .. }
    ));

    worker.send(&ping("shared-id")).expect("send ping");
    assert!(matches!(
        worker.read_response().expect("pong response"),
        WorkerResponse::Pong { request_id } if request_id == "shared-id"
    ));

    let fetch = WorkerRequest::Fetch {
        protocol_version: PROTOCOL_VERSION,
        request_id: "shared-id".to_owned(),
        url: "https://example.com".to_owned(),
        timeout_ms: 1,
        max_bytes: 1,
    };
    worker.send(&fetch).expect("send duplicate fetch");
    match worker.read_response().expect("duplicate-id error") {
        WorkerResponse::Error {
            request_id,
            code: WorkerErrorCode::InvalidRequest,
            message,
        } => {
            assert_eq!(request_id.as_deref(), Some("shared-id"));
            assert!(message.contains("already been used"));
        }
        other => panic!("expected duplicate-id error, got {other:?}"),
    }

    worker.send(&shutdown()).expect("send shutdown");
    assert_eq!(
        worker.read_response().expect("shutdown response"),
        WorkerResponse::ShutdownAck
    );
    let (success, stderr) = worker.finish().expect("reap worker");
    assert!(success, "worker exited unsuccessfully: {stderr}");
    assert!(stderr.is_empty(), "unexpected worker diagnostics: {stderr}");
}

#[test]
fn compiled_worker_keeps_protocol_errors_on_stdout_and_diagnostics_on_stderr() {
    let mut worker = WorkerProcess::spawn().expect("spawn worker");
    assert!(matches!(
        worker.read_response().expect("ready response"),
        WorkerResponse::Ready { .. }
    ));

    let stdin = worker.stdin.as_mut().expect("worker stdin is open");
    stdin
        .write_all(b"not-json\n")
        .expect("send malformed frame");
    stdin.flush().expect("flush malformed frame");

    match worker.read_response().expect("malformed-frame response") {
        WorkerResponse::Error {
            request_id: None,
            code: WorkerErrorCode::MalformedFrame,
            message,
        } => assert!(message.contains("protocol")),
        other => panic!("expected malformed-frame error, got {other:?}"),
    }

    let (success, stderr) = worker.finish().expect("reap worker");
    assert!(!success, "malformed protocol input must fail the worker");
    assert!(
        stderr.contains("protocol stopped"),
        "expected diagnostic on stderr, got: {stderr}"
    );
    assert!(
        !stderr.contains("{\"type\""),
        "stderr must not carry protocol frames"
    );
}

#[test]
fn compiled_worker_reports_not_found_when_cancel_arrives_after_completion() {
    let mut worker = WorkerProcess::spawn().expect("spawn worker");
    assert!(matches!(
        worker.read_response().expect("ready response"),
        WorkerResponse::Ready { .. }
    ));

    let fetch = WorkerRequest::Fetch {
        protocol_version: PROTOCOL_VERSION,
        request_id: "finished-fetch".to_owned(),
        url: "test://deterministic-invalid-scheme".to_owned(),
        timeout_ms: 1,
        max_bytes: 1,
    };
    worker.send(&fetch).expect("send invalid-scheme fetch");
    assert!(matches!(
        worker.read_response().expect("fetch started"),
        WorkerResponse::FetchStarted { request_id } if request_id == "finished-fetch"
    ));
    assert!(matches!(
        worker.read_response().expect("fetch error"),
        WorkerResponse::Error {
            request_id: Some(request_id),
            code: WorkerErrorCode::FetchFailed,
            ..
        } if request_id == "finished-fetch"
    ));

    let cancel = WorkerRequest::Cancel {
        protocol_version: PROTOCOL_VERSION,
        request_id: "finished-fetch".to_owned(),
    };
    worker.send(&cancel).expect("send late cancel");
    assert!(matches!(
        worker.read_response().expect("late-cancel response"),
        WorkerResponse::Error {
            request_id: Some(request_id),
            code: WorkerErrorCode::NotFound,
            ..
        } if request_id == "finished-fetch"
    ));

    worker.send(&shutdown()).expect("send shutdown");
    assert_eq!(
        worker.read_response().expect("shutdown response"),
        WorkerResponse::ShutdownAck
    );
    let (success, stderr) = worker.finish().expect("reap worker");
    assert!(success, "worker exited unsuccessfully: {stderr}");
    assert!(stderr.is_empty(), "unexpected worker diagnostics: {stderr}");
}

#[test]
fn compiled_worker_exits_cleanly_on_parent_eof() {
    let mut worker = WorkerProcess::spawn().expect("spawn worker");
    assert!(matches!(
        worker.read_response().expect("ready response"),
        WorkerResponse::Ready { .. }
    ));
    worker.close_stdin();

    let (success, stderr) = worker.finish().expect("reap worker after EOF");
    assert!(success, "worker exited unsuccessfully: {stderr}");
    assert!(stderr.is_empty(), "unexpected worker diagnostics: {stderr}");
}
