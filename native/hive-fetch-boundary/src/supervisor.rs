//! A synchronous, typed supervisor for the isolated research worker.
//!
//! The supervisor owns the child process and all of its pipes. It performs the
//! `Ready` handshake before exposing the worker, routes responses through the
//! protocol session reader, drains stdout/stderr on dedicated threads, bounds
//! submitted fetches, and makes shutdown explicit: graceful acknowledgement is
//! distinct from a watchdog-forced kill. It deliberately does not restart a
//! worker automatically; restart/backoff is an application policy that must be
//! chosen above this transport boundary.

use std::collections::{HashSet, VecDeque};
use std::fmt;
use std::io::{self, BufReader, Read};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, ExitStatus, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::thread::{self, JoinHandle};
use std::time::{Duration, Instant};

use crate::protocol::{
    read_response_into_session, write_request, CodecConfig, ProtocolError, ProtocolSession,
    WorkerRequest, WorkerResponse, PROTOCOL_VERSION,
};

const DEFAULT_MAX_IN_FLIGHT: usize = 8;
const MAX_STDERR_BYTES: usize = 64 * 1024;
const POLL_INTERVAL: Duration = Duration::from_millis(10);

type ResponseMessage = Result<WorkerResponse, String>;

/// Configuration for one worker process.
#[derive(Clone, Debug)]
pub struct SupervisorConfig {
    /// Executable to launch. The supervisor does not guess a repository or
    /// Cargo target path; the embedding application owns binary discovery.
    pub command: PathBuf,
    pub codec: CodecConfig,
    pub max_in_flight: usize,
    pub startup_timeout: Duration,
    pub request_timeout: Duration,
    pub shutdown_timeout: Duration,
}

impl SupervisorConfig {
    pub fn new(command: impl Into<PathBuf>) -> Self {
        Self {
            command: command.into(),
            codec: CodecConfig::default(),
            max_in_flight: DEFAULT_MAX_IN_FLIGHT,
            startup_timeout: Duration::from_secs(3),
            request_timeout: Duration::from_secs(30),
            shutdown_timeout: Duration::from_secs(3),
        }
    }

    fn validate(&self) -> Result<(), SupervisorError> {
        self.codec.validate().map_err(SupervisorError::protocol)?;
        if self.command.as_os_str().is_empty() {
            return Err(SupervisorError::InvalidConfiguration(
                "worker command path is empty".to_owned(),
            ));
        }
        if self.max_in_flight == 0 {
            return Err(SupervisorError::InvalidConfiguration(
                "max_in_flight must be greater than zero".to_owned(),
            ));
        }
        if self.startup_timeout.is_zero()
            || self.request_timeout.is_zero()
            || self.shutdown_timeout.is_zero()
        {
            return Err(SupervisorError::InvalidConfiguration(
                "supervisor timeouts must be greater than zero".to_owned(),
            ));
        }
        Ok(())
    }
}

/// Why a supervisor operation failed.
#[derive(Debug)]
pub enum SupervisorError {
    Io(io::Error),
    Protocol(String),
    InvalidConfiguration(String),
    Closed,
    NotReady,
    InFlightLimit { limit: usize },
    DuplicateRequest(String),
    Timeout(&'static str),
    WorkerExited(Option<ExitStatus>),
    ShutdownRequested,
}

impl SupervisorError {
    fn protocol(error: ProtocolError) -> Self {
        Self::Protocol(error.to_string())
    }
}

impl fmt::Display for SupervisorError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => write!(f, "supervisor I/O failed: {error}"),
            Self::Protocol(message) => write!(f, "supervisor protocol failed: {message}"),
            Self::InvalidConfiguration(message) => {
                write!(f, "invalid supervisor configuration: {message}")
            }
            Self::Closed => write!(f, "worker supervisor is closed"),
            Self::NotReady => write!(f, "worker did not complete its Ready handshake"),
            Self::InFlightLimit { limit } => write!(f, "worker in-flight limit reached: {limit}"),
            Self::DuplicateRequest(request_id) => {
                write!(f, "request is already in flight: {request_id}")
            }
            Self::Timeout(operation) => write!(f, "supervisor timed out while {operation}"),
            Self::WorkerExited(status) => write!(f, "worker exited unexpectedly: {status:?}"),
            Self::ShutdownRequested => write!(f, "worker shutdown has already been requested"),
        }
    }
}

impl std::error::Error for SupervisorError {}

impl From<io::Error> for SupervisorError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

/// The result of attempting graceful shutdown.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ShutdownOutcome {
    /// The worker acknowledged shutdown and exited before the watchdog.
    Graceful,
    /// The worker did not complete the graceful path before the watchdog and
    /// was killed and reaped. This is an expected, inspectable outcome rather
    /// than a silent fallback.
    Forced,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum SupervisorState {
    Running,
    Closed,
}

/// Owns one compiled worker process and its typed NDJSON session.
///
/// `WorkerSupervisor` is intentionally synchronous and must be used from a
/// blocking thread when embedded in a UI or async runtime. It is not `Clone`:
/// one owner serializes writes and response routing, while dedicated threads
/// only drain the child pipes.
pub struct WorkerSupervisor {
    child: Child,
    stdin: Option<ChildStdin>,
    responses: Receiver<ResponseMessage>,
    response_thread: Option<JoinHandle<()>>,
    stderr: Option<(Receiver<String>, JoinHandle<()>)>,
    buffered: VecDeque<WorkerResponse>,
    /// Every request ID submitted in this worker session. The worker's
    /// protocol reserves IDs for the full session, so terminal completion does
    /// not make an ID reusable.
    used_request_ids: HashSet<String>,
    in_flight: HashSet<String>,
    config: SupervisorConfig,
    state: SupervisorState,
}

impl WorkerSupervisor {
    /// Starts a worker and waits for a valid `Ready` response.
    pub fn spawn(config: SupervisorConfig) -> Result<Self, SupervisorError> {
        config.validate()?;
        let mut child = Command::new(&config.command)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;
        let stdin = child.stdin.take().ok_or_else(|| {
            SupervisorError::Io(io::Error::new(
                io::ErrorKind::Other,
                "worker stdin was not piped",
            ))
        })?;
        let stdout = child.stdout.take().ok_or_else(|| {
            SupervisorError::Io(io::Error::new(
                io::ErrorKind::Other,
                "worker stdout was not piped",
            ))
        })?;
        let stderr = child.stderr.take().ok_or_else(|| {
            SupervisorError::Io(io::Error::new(
                io::ErrorKind::Other,
                "worker stderr was not piped",
            ))
        })?;

        let (response_sender, response_receiver) = mpsc::channel();
        let codec = config.codec;
        let response_thread =
            thread::spawn(move || drain_responses(stdout, codec, response_sender));
        let (stderr_sender, stderr_receiver) = mpsc::channel();
        let stderr_thread = thread::spawn(move || drain_stderr(stderr, stderr_sender));

        let mut supervisor = Self {
            child,
            stdin: Some(stdin),
            responses: response_receiver,
            response_thread: Some(response_thread),
            stderr: Some((stderr_receiver, stderr_thread)),
            buffered: VecDeque::new(),
            used_request_ids: HashSet::new(),
            in_flight: HashSet::new(),
            config,
            state: SupervisorState::Running,
        };

        match supervisor.receive(supervisor.config.startup_timeout)? {
            WorkerResponse::Ready { protocol_version } if protocol_version == PROTOCOL_VERSION => {
                Ok(supervisor)
            }
            other => {
                supervisor.terminate();
                Err(SupervisorError::Protocol(format!(
                    "expected Ready handshake, received {other:?}"
                )))
            }
        }
    }

    pub fn is_running(&self) -> bool {
        self.state == SupervisorState::Running
    }

    pub fn in_flight_count(&self) -> usize {
        self.in_flight.len()
    }

    /// Sends a validated request. Fetch request IDs count against the
    /// supervisor's in-flight limit. Ping IDs are also reserved for the
    /// session; Cancel references an existing fetch ID and does not reserve a
    /// second ID.
    pub fn submit(&mut self, request: WorkerRequest) -> Result<(), SupervisorError> {
        self.ensure_running()?;
        crate::protocol::validate_request(&request).map_err(SupervisorError::protocol)?;
        if matches!(request, WorkerRequest::Shutdown { .. }) {
            return Err(SupervisorError::ShutdownRequested);
        }
        let new_request_id = match &request {
            WorkerRequest::Fetch { request_id, .. } | WorkerRequest::Ping { request_id, .. } => {
                Some(request_id.as_str())
            }
            WorkerRequest::Cancel { .. } | WorkerRequest::Shutdown { .. } => None,
        };
        let fetch_id = match &request {
            WorkerRequest::Fetch { request_id, .. } => Some(request_id.as_str()),
            _ => None,
        };
        if let Some(request_id) = new_request_id {
            if self.used_request_ids.contains(request_id) {
                return Err(SupervisorError::DuplicateRequest(request_id.to_owned()));
            }
        }
        if fetch_id.is_some() && self.in_flight.len() >= self.config.max_in_flight {
            return Err(SupervisorError::InFlightLimit {
                limit: self.config.max_in_flight,
            });
        }

        let stdin = self.stdin.as_mut().ok_or(SupervisorError::Closed)?;
        write_request(stdin, &request, self.config.codec).map_err(SupervisorError::protocol)?;
        if let Some(request_id) = new_request_id {
            self.used_request_ids.insert(request_id.to_owned());
        }
        if let Some(request_id) = fetch_id {
            self.in_flight.insert(request_id.to_owned());
        }
        Ok(())
    }

    /// Convenience method for a synchronous ping health check.
    pub fn ping(&mut self, request_id: impl Into<String>) -> Result<(), SupervisorError> {
        let request_id = request_id.into();
        self.submit(WorkerRequest::Ping {
            protocol_version: PROTOCOL_VERSION,
            request_id: request_id.clone(),
        })?;
        match self.wait_for(&request_id, self.config.request_timeout)? {
            WorkerResponse::Pong { .. } => Ok(()),
            response => Err(SupervisorError::Protocol(format!(
                "expected Pong for {request_id}, received {response:?}"
            ))),
        }
    }

    /// Waits for the terminal response associated with a fetch request.
    /// Intermediate `FetchStarted` and unrelated responses are retained/routed
    /// rather than discarded.
    pub fn wait_for_fetch(
        &mut self,
        request_id: &str,
        timeout: Duration,
    ) -> Result<WorkerResponse, SupervisorError> {
        self.wait_for(request_id, timeout)
    }

    /// Polls one response without waiting longer than `timeout`.
    pub fn poll(&mut self, timeout: Duration) -> Result<WorkerResponse, SupervisorError> {
        self.ensure_running()?;
        let response = if let Some(response) = self.buffered.pop_front() {
            response
        } else {
            self.receive(timeout)?
        };
        self.observe(&response);
        Ok(response)
    }

    /// Requests cooperative shutdown, then enforces a kill-and-reap watchdog
    /// if the worker cannot acknowledge and exit in the configured window.
    pub fn shutdown(&mut self) -> Result<ShutdownOutcome, SupervisorError> {
        if self.state == SupervisorState::Closed {
            return Ok(ShutdownOutcome::Graceful);
        }
        let shutdown = WorkerRequest::Shutdown {
            protocol_version: PROTOCOL_VERSION,
        };
        let send_result = self
            .stdin
            .as_mut()
            .ok_or(SupervisorError::Closed)
            .and_then(|stdin| {
                write_request(stdin, &shutdown, self.config.codec)
                    .map_err(SupervisorError::protocol)
            });
        if let Err(error) = send_result {
            self.terminate();
            return Err(error);
        }

        let deadline = Instant::now() + self.config.shutdown_timeout;
        let mut acknowledged = false;
        while Instant::now() < deadline {
            let remaining = deadline.saturating_duration_since(Instant::now());
            match self.receive(remaining.min(POLL_INTERVAL)) {
                Ok(WorkerResponse::ShutdownAck) => {
                    acknowledged = true;
                    break;
                }
                Ok(response) => {
                    self.observe(&response);
                    self.buffered.push_back(response);
                }
                Err(SupervisorError::Timeout(_)) => {}
                Err(_) => break,
            }
        }
        self.stdin.take();
        let outcome = if acknowledged {
            if wait_for_child(&mut self.child, self.config.shutdown_timeout)?.is_some() {
                ShutdownOutcome::Graceful
            } else {
                self.kill_and_reap()?;
                ShutdownOutcome::Forced
            }
        } else {
            self.kill_and_reap()?;
            ShutdownOutcome::Forced
        };
        self.state = SupervisorState::Closed;
        self.join_drains()?;
        Ok(outcome)
    }

    fn wait_for(
        &mut self,
        request_id: &str,
        timeout: Duration,
    ) -> Result<WorkerResponse, SupervisorError> {
        self.ensure_running()?;
        let deadline = Instant::now() + timeout;
        loop {
            if let Some(index) = self.buffered.iter().position(|response| {
                response_request_id(response) == Some(request_id) && is_terminal(response)
            }) {
                let response = self.buffered.remove(index).expect("response index exists");
                self.observe(&response);
                return Ok(response);
            }
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                return Err(SupervisorError::Timeout("waiting for worker response"));
            }
            let response = self.receive(remaining)?;
            if response_request_id(&response) == Some(request_id) && is_terminal(&response) {
                self.observe(&response);
                return Ok(response);
            }
            self.observe(&response);
            self.buffered.push_back(response);
        }
    }

    fn receive(&mut self, timeout: Duration) -> Result<WorkerResponse, SupervisorError> {
        match self.responses.recv_timeout(timeout) {
            Ok(Ok(response)) => Ok(response),
            Ok(Err(message)) => {
                let error = SupervisorError::Protocol(message);
                self.fail_worker();
                Err(error)
            }
            Err(mpsc::RecvTimeoutError::Timeout) => {
                Err(SupervisorError::Timeout("reading worker output"))
            }
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                let status = self.child.try_wait().ok().flatten();
                let error = SupervisorError::WorkerExited(status);
                self.fail_worker();
                Err(error)
            }
        }
    }

    fn observe(&mut self, response: &WorkerResponse) {
        if let Some(request_id) = response_request_id(response) {
            if is_terminal(response) {
                self.in_flight.remove(request_id);
            }
        }
    }

    fn ensure_running(&self) -> Result<(), SupervisorError> {
        match self.state {
            SupervisorState::Running => Ok(()),
            SupervisorState::Closed => Err(SupervisorError::Closed),
        }
    }

    fn fail_worker(&mut self) {
        self.stdin.take();
        self.state = SupervisorState::Closed;
        let _ = self.kill_and_reap();
    }

    fn terminate(&mut self) {
        self.stdin.take();
        let _ = self.kill_and_reap();
        self.state = SupervisorState::Closed;
    }

    fn kill_and_reap(&mut self) -> io::Result<()> {
        if self.child.try_wait()?.is_some() {
            return Ok(());
        }
        if let Err(kill_error) = self.child.kill() {
            // The child may have exited between try_wait and kill. Re-check
            // before surfacing the kill error so a normal race is not treated
            // as a failed watchdog cleanup.
            if self.child.try_wait()?.is_some() {
                return Ok(());
            }
            return Err(kill_error);
        }
        self.child.wait()?;
        Ok(())
    }

    fn join_drains(&mut self) -> io::Result<()> {
        if let Some(thread) = self.response_thread.take() {
            thread
                .join()
                .map_err(|_| io::Error::new(io::ErrorKind::Other, "response thread panicked"))?;
        }
        if let Some((receiver, thread)) = self.stderr.take() {
            let _ = receiver.recv_timeout(self.config.shutdown_timeout);
            thread
                .join()
                .map_err(|_| io::Error::new(io::ErrorKind::Other, "stderr thread panicked"))?;
        }
        Ok(())
    }
}

impl Drop for WorkerSupervisor {
    fn drop(&mut self) {
        self.stdin.take();
        let _ = self.kill_and_reap();
        if let Some(thread) = self.response_thread.take() {
            let _ = thread.join();
        }
        if let Some((_, thread)) = self.stderr.take() {
            let _ = thread.join();
        }
    }
}

fn drain_responses(stdout: impl Read, codec: CodecConfig, sender: mpsc::Sender<ResponseMessage>) {
    let mut reader = BufReader::new(stdout);
    let mut session = ProtocolSession::new();
    loop {
        match read_response_into_session(&mut reader, codec, &mut session) {
            Ok(Some(response)) => {
                if sender.send(Ok(response)).is_err() {
                    break;
                }
            }
            Ok(None) => {
                let _ = sender.send(Err("worker stdout closed".to_owned()));
                break;
            }
            Err(error) => {
                let _ = sender.send(Err(error.to_string()));
                break;
            }
        }
    }
}

fn drain_stderr(mut stderr: impl Read, sender: mpsc::Sender<String>) {
    let mut retained = Vec::new();
    let mut buffer = [0_u8; 4096];
    loop {
        match stderr.read(&mut buffer) {
            Ok(0) => break,
            Ok(count) => {
                let remaining = MAX_STDERR_BYTES.saturating_sub(retained.len());
                if remaining > 0 {
                    retained.extend_from_slice(&buffer[..count.min(remaining)]);
                }
                // Continue draining after the retained prefix is full. A
                // noisy child must never block on stderr while the supervisor
                // waits for stdout or process exit.
            }
            Err(_) => break,
        }
    }
    let output = String::from_utf8_lossy(&retained).into_owned();
    let _ = sender.send(output);
}

fn wait_for_child(child: &mut Child, timeout: Duration) -> io::Result<Option<ExitStatus>> {
    let deadline = Instant::now() + timeout;
    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(Some(status));
        }
        if Instant::now() >= deadline {
            return Ok(None);
        }
        thread::sleep(POLL_INTERVAL);
    }
}

fn response_request_id(response: &WorkerResponse) -> Option<&str> {
    match response {
        WorkerResponse::FetchStarted { request_id }
        | WorkerResponse::FetchCompleted { request_id, .. }
        | WorkerResponse::Cancelled { request_id }
        | WorkerResponse::Pong { request_id }
        | WorkerResponse::Error {
            request_id: Some(request_id),
            ..
        } => Some(request_id),
        WorkerResponse::Ready { .. }
        | WorkerResponse::Error {
            request_id: None, ..
        }
        | WorkerResponse::ShutdownAck => None,
    }
}

fn is_terminal(response: &WorkerResponse) -> bool {
    matches!(
        response,
        WorkerResponse::FetchCompleted { .. }
            | WorkerResponse::Cancelled { .. }
            | WorkerResponse::Error {
                request_id: Some(_),
                ..
            }
            | WorkerResponse::Pong { .. }
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn config_rejects_zero_in_flight_and_timeouts() {
        let mut config = SupervisorConfig::new("worker");
        config.max_in_flight = 0;
        assert!(matches!(
            config.validate(),
            Err(SupervisorError::InvalidConfiguration(message)) if message.contains("max_in_flight")
        ));
        config.max_in_flight = 1;
        config.shutdown_timeout = Duration::ZERO;
        assert!(matches!(
            config.validate(),
            Err(SupervisorError::InvalidConfiguration(message)) if message.contains("timeouts")
        ));
    }

    #[test]
    fn terminal_response_classification_is_explicit() {
        assert!(is_terminal(&WorkerResponse::FetchCompleted {
            request_id: "fetch".to_owned(),
            status: 200,
            final_url: "https://example.com".to_owned(),
            content_type: None,
            body_base64: crate::protocol::encode_body(b"ok"),
            redirect_count: 0,
        }));
        assert!(!is_terminal(&WorkerResponse::FetchStarted {
            request_id: "fetch".to_owned(),
        }));
        assert_eq!(
            response_request_id(&WorkerResponse::Error {
                request_id: None,
                code: crate::protocol::WorkerErrorCode::Internal,
                message: "worker error".to_owned(),
            }),
            None
        );
    }
}
