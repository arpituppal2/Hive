#![cfg(feature = "test-support")]

use std::io;
use std::path::PathBuf;
use std::time::Duration;

use hive_fetch_boundary::protocol::WorkerErrorCode;
use hive_fetch_boundary::research_client::{FetchOptions, ResearchClient, ResearchClientError};
use hive_fetch_boundary::supervisor::{ShutdownOutcome, SupervisorConfig};

fn binary_path(env_name: &str, file_name: &str) -> io::Result<PathBuf> {
    if let Some(path) = std::env::var_os(env_name) {
        return Ok(PathBuf::from(path));
    }
    let test_binary = std::env::current_exe()?;
    let profile_dir = test_binary
        .parent()
        .and_then(|deps| deps.parent())
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "test profile directory missing"))?;
    let binary = profile_dir.join(format!("{file_name}{}", std::env::consts::EXE_SUFFIX));
    if binary.is_file() {
        Ok(binary)
    } else {
        Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("test worker binary not found at {}", binary.display()),
        ))
    }
}

#[test]
fn client_maps_fixture_response_to_source_provenance() {
    let config = SupervisorConfig::new(
        binary_path(
            "CARGO_BIN_EXE_hive_research_fixture_worker",
            "hive-research-fixture-worker",
        )
        .expect("fixture worker binary"),
    );
    let mut client = ResearchClient::spawn(config).expect("research client startup");
    let record = client
        .fetch(
            FetchOptions::new("https://fixture.example/request"),
            Duration::from_secs(2),
        )
        .expect("fixture research fetch");

    assert_eq!(record.requested_url, "https://fixture.example/request");
    assert_eq!(record.final_url, "https://fixture.example/final");
    assert_eq!(record.status, 200);
    assert_eq!(record.content_type.as_deref(), Some("text/plain"));
    assert_eq!(record.body, b"fixture body");
    assert_eq!(
        record.content_hash_sha256,
        "ca260f20e9412d1ac5e1e30014e8592c75e07ad93446586497e04863084b52a3"
    );
    assert!(record.retrieved_at_unix_ms > 0);
    assert_eq!(record.redirect_count, 2);
    assert_eq!(record.capture_method, "swarm-research");
}

#[test]
fn client_maps_cancel_after_terminal_fetch_to_already_finished() {
    let config = SupervisorConfig::new(
        binary_path("CARGO_BIN_EXE_hive_fetch_worker", "hive-fetch-worker").expect("worker binary"),
    );
    let mut client = ResearchClient::spawn(config).expect("research client startup");
    let pending = client
        .begin_fetch(FetchOptions::new("test://deterministic-invalid-scheme"))
        .expect("begin fetch");
    let fetch_error = client
        .wait_fetch(&pending, Duration::from_secs(2))
        .expect_err("invalid scheme should fail");
    assert!(matches!(
        fetch_error,
        ResearchClientError::Worker {
            code: WorkerErrorCode::FetchFailed,
            ..
        }
    ));
    assert!(matches!(
        client.cancel(&pending, Duration::from_secs(2)),
        Err(ResearchClientError::AlreadyFinished { request_id })
            if request_id == pending.request_id
    ));
    assert_eq!(
        client.shutdown().expect("shutdown research worker"),
        ShutdownOutcome::Graceful
    );
}

#[test]
fn client_maps_real_worker_fetch_error_and_shuts_down_cleanly() {
    let config = SupervisorConfig::new(
        binary_path("CARGO_BIN_EXE_hive_fetch_worker", "hive-fetch-worker").expect("worker binary"),
    );
    let mut client = ResearchClient::spawn(config).expect("research client startup");
    let error = client
        .fetch(
            FetchOptions::new("test://deterministic-invalid-scheme"),
            Duration::from_secs(2),
        )
        .expect_err("invalid scheme should fail");
    assert!(matches!(
        error,
        ResearchClientError::Worker {
            code: WorkerErrorCode::FetchFailed,
            ..
        }
    ));
    assert_eq!(
        client.shutdown().expect("shutdown research worker"),
        ShutdownOutcome::Graceful
    );
}
