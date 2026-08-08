use std::io;
use std::path::PathBuf;
use std::time::Duration;

use hive_fetch_boundary::protocol::{
    WorkerErrorCode, WorkerRequest, WorkerResponse, PROTOCOL_VERSION,
};
use hive_fetch_boundary::supervisor::{
    ShutdownOutcome, SupervisorConfig, SupervisorError, WorkerSupervisor,
};

fn worker_binary_path() -> io::Result<PathBuf> {
    if let Some(path) = std::env::var_os("CARGO_BIN_EXE_hive_fetch_worker") {
        return Ok(PathBuf::from(path));
    }
    let test_binary = std::env::current_exe()?;
    let profile_dir = test_binary
        .parent()
        .and_then(|deps| deps.parent())
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "test profile directory missing"))?;
    let worker = profile_dir.join(format!("hive-fetch-worker{}", std::env::consts::EXE_SUFFIX));
    if worker.is_file() {
        Ok(worker)
    } else {
        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("worker binary not found at {}", worker.display()),
        ))
    }
}

#[cfg(feature = "test-support")]
fn hostile_worker_binary_path() -> io::Result<PathBuf> {
    if let Some(path) = std::env::var_os("CARGO_BIN_EXE_hive_hostile_worker") {
        return Ok(PathBuf::from(path));
    }
    let test_binary = std::env::current_exe()?;
    let profile_dir = test_binary
        .parent()
        .and_then(|deps| deps.parent())
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "test profile directory missing"))?;
    let worker = profile_dir.join(format!(
        "hive-hostile-worker{}",
        std::env::consts::EXE_SUFFIX
    ));
    if worker.is_file() {
        Ok(worker)
    } else {
        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("hostile worker binary not found at {}", worker.display()),
        ))
    }
}

fn supervisor() -> WorkerSupervisor {
    let mut config = SupervisorConfig::new(worker_binary_path().expect("worker binary"));
    config.request_timeout = Duration::from_secs(2);
    config.shutdown_timeout = Duration::from_secs(2);
    WorkerSupervisor::spawn(config).expect("worker supervisor startup")
}

#[test]
fn supervisor_performs_ready_ping_and_graceful_shutdown() {
    let mut supervisor = supervisor();
    assert!(supervisor.is_running());
    supervisor.ping("health-1").expect("ping worker");
    assert_eq!(supervisor.in_flight_count(), 0);
    assert_eq!(
        supervisor.shutdown().expect("shutdown worker"),
        ShutdownOutcome::Graceful
    );
    assert!(!supervisor.is_running());
}

#[test]
fn supervisor_routes_fetch_terminal_response_and_releases_slot() {
    let mut supervisor = supervisor();
    supervisor
        .submit(WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: "invalid-scheme".to_owned(),
            url: "test://deterministic-invalid-scheme".to_owned(),
            timeout_ms: 1,
            max_bytes: 1,
        })
        .expect("submit fetch");
    assert_eq!(supervisor.in_flight_count(), 1);

    let response = supervisor
        .wait_for_fetch("invalid-scheme", Duration::from_secs(2))
        .expect("fetch terminal response");
    assert!(matches!(
        response,
        WorkerResponse::Error {
            request_id: Some(request_id),
            code: WorkerErrorCode::FetchFailed,
            ..
        } if request_id == "invalid-scheme"
    ));
    assert_eq!(supervisor.in_flight_count(), 0);
    assert_eq!(
        supervisor.shutdown().expect("shutdown worker"),
        ShutdownOutcome::Graceful
    );
}

#[test]
fn supervisor_rejects_duplicate_request_ids_across_control_and_fetch() {
    let mut supervisor = supervisor();
    supervisor.ping("shared-id").expect("first request");
    let result = supervisor.submit(WorkerRequest::Fetch {
        protocol_version: PROTOCOL_VERSION,
        request_id: "shared-id".to_owned(),
        url: "test://deterministic-invalid-scheme".to_owned(),
        timeout_ms: 1,
        max_bytes: 1,
    });
    assert!(matches!(
        result,
        Err(SupervisorError::DuplicateRequest(request_id)) if request_id == "shared-id"
    ));
    assert_eq!(
        supervisor.shutdown().expect("shutdown worker"),
        ShutdownOutcome::Graceful
    );
}

#[test]
fn supervisor_rejects_shutdown_submitted_as_a_generic_request() {
    let mut supervisor = supervisor();
    let result = supervisor.submit(WorkerRequest::Shutdown {
        protocol_version: PROTOCOL_VERSION,
    });
    assert!(matches!(result, Err(SupervisorError::ShutdownRequested)));
    assert!(supervisor.is_running());
    assert_eq!(
        supervisor.shutdown().expect("shutdown worker"),
        ShutdownOutcome::Graceful
    );
}

#[cfg(feature = "test-support")]
#[test]
fn supervisor_forces_shutdown_of_non_cooperative_worker() {
    let mut config =
        SupervisorConfig::new(hostile_worker_binary_path().expect("hostile worker binary"));
    config.shutdown_timeout = Duration::from_millis(120);
    config.startup_timeout = Duration::from_secs(2);
    let mut supervisor = WorkerSupervisor::spawn(config).expect("hostile worker startup");
    assert!(supervisor.is_running());
    assert_eq!(
        supervisor
            .shutdown()
            .expect("force hostile worker shutdown"),
        ShutdownOutcome::Forced
    );
    assert!(!supervisor.is_running());
}

#[test]
fn supervisor_enforces_fetch_in_flight_limit_before_worker_response() {
    let mut config = SupervisorConfig::new(worker_binary_path().expect("worker binary"));
    config.max_in_flight = 1;
    config.request_timeout = Duration::from_secs(2);
    config.shutdown_timeout = Duration::from_secs(2);
    let mut supervisor = WorkerSupervisor::spawn(config).expect("worker supervisor startup");

    supervisor
        .submit(WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: "first-fetch".to_owned(),
            url: "test://deterministic-invalid-scheme".to_owned(),
            timeout_ms: 1,
            max_bytes: 1,
        })
        .expect("submit first fetch");
    let result = supervisor.submit(WorkerRequest::Fetch {
        protocol_version: PROTOCOL_VERSION,
        request_id: "second-fetch".to_owned(),
        url: "test://deterministic-invalid-scheme".to_owned(),
        timeout_ms: 1,
        max_bytes: 1,
    });
    assert!(matches!(
        result,
        Err(SupervisorError::InFlightLimit { limit: 1 })
    ));

    let _ = supervisor
        .wait_for_fetch("first-fetch", Duration::from_secs(2))
        .expect("first fetch terminal response");
    assert_eq!(
        supervisor.shutdown().expect("shutdown worker"),
        ShutdownOutcome::Graceful
    );
}
