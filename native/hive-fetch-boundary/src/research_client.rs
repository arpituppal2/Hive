//! Typed application boundary above the worker supervisor.
//!
//! `ResearchClient` turns the worker's protocol response into a bounded,
//! source-shaped record suitable for a later Honeycomb adapter. It does not
//! persist data, extract HTML, invent titles/citations, or widen the worker's
//! network policy. Callers own the returned bytes and decide whether they are
//! retained.

use std::fmt;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

use crate::protocol::{WorkerErrorCode, WorkerRequest, WorkerResponse, PROTOCOL_VERSION};
use crate::supervisor::{SupervisorConfig, SupervisorError, WorkerSupervisor};

static NEXT_REQUEST_ID: AtomicU64 = AtomicU64::new(1);

/// Request settings for one research fetch.
#[derive(Clone, Debug)]
pub struct FetchOptions {
    pub url: String,
    pub timeout_ms: u64,
    pub max_bytes: usize,
}

impl FetchOptions {
    pub fn new(url: impl Into<String>) -> Self {
        Self {
            url: url.into(),
            timeout_ms: 15_000,
            max_bytes: 5 * 1024 * 1024,
        }
    }
}

/// A fetched source payload with enough provenance for a later Honeycomb
/// adapter. `body` is bounded by the request and worker protocol limits.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ResearchSourceRecord {
    pub requested_url: String,
    pub final_url: String,
    pub status: u16,
    pub content_type: Option<String>,
    pub body: Vec<u8>,
    pub content_hash_sha256: String,
    pub retrieved_at_unix_ms: u128,
    pub redirect_count: usize,
    pub capture_method: &'static str,
}

/// A fetch that has been submitted and can be waited on or cancelled.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PendingFetch {
    pub request_id: String,
    pub requested_url: String,
}

/// Errors exposed by the typed research boundary.
#[derive(Debug)]
pub enum ResearchClientError {
    Supervisor(SupervisorError),
    Worker {
        request_id: String,
        code: WorkerErrorCode,
        message: String,
    },
    Cancelled {
        request_id: String,
    },
    AlreadyFinished {
        request_id: String,
    },
    UnexpectedResponse {
        request_id: String,
        response: String,
    },
    Clock(std::time::SystemTimeError),
}

impl fmt::Display for ResearchClientError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Supervisor(error) => write!(f, "research supervisor failed: {error}"),
            Self::Worker {
                request_id,
                code,
                message,
            } => write!(
                f,
                "research fetch {request_id} failed ({code:?}): {message}"
            ),
            Self::Cancelled { request_id } => {
                write!(f, "research fetch {request_id} was cancelled")
            }
            Self::AlreadyFinished { request_id } => {
                write!(f, "research fetch {request_id} is no longer active")
            }
            Self::UnexpectedResponse {
                request_id,
                response,
            } => write!(
                f,
                "unexpected response for research fetch {request_id}: {response}"
            ),
            Self::Clock(error) => write!(f, "could not record research retrieval time: {error}"),
        }
    }
}

impl std::error::Error for ResearchClientError {}

impl From<SupervisorError> for ResearchClientError {
    fn from(error: SupervisorError) -> Self {
        Self::Supervisor(error)
    }
}

/// Owns one typed supervisor session. Use from a blocking thread; this API is
/// intentionally synchronous because the underlying DNS and process I/O are
/// synchronous.
pub struct ResearchClient {
    supervisor: WorkerSupervisor,
}

impl ResearchClient {
    pub fn spawn(config: SupervisorConfig) -> Result<Self, ResearchClientError> {
        Ok(Self {
            supervisor: WorkerSupervisor::spawn(config)?,
        })
    }

    pub fn begin_fetch(
        &mut self,
        options: FetchOptions,
    ) -> Result<PendingFetch, ResearchClientError> {
        let request_id = next_request_id();
        self.supervisor.submit(WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: request_id.clone(),
            url: options.url.clone(),
            timeout_ms: options.timeout_ms,
            max_bytes: options.max_bytes,
        })?;
        Ok(PendingFetch {
            request_id,
            requested_url: options.url,
        })
    }

    /// Waits for a terminal response. A timeout does not implicitly cancel the
    /// worker job: callers that need to release its in-flight slot should call
    /// `cancel` with the returned `PendingFetch`.
    pub fn wait_fetch(
        &mut self,
        pending: &PendingFetch,
        timeout: std::time::Duration,
    ) -> Result<ResearchSourceRecord, ResearchClientError> {
        let response = self
            .supervisor
            .wait_for_fetch(&pending.request_id, timeout)?;
        self.map_terminal_response(pending, response)
    }

    pub fn fetch(
        &mut self,
        options: FetchOptions,
        timeout: std::time::Duration,
    ) -> Result<ResearchSourceRecord, ResearchClientError> {
        let pending = self.begin_fetch(options)?;
        self.wait_fetch(&pending, timeout)
    }

    /// Requests cooperative cancellation and waits for the worker's terminal
    /// cancellation response. A forced process shutdown remains owned by the
    /// supervisor's explicit `shutdown` method.
    pub fn cancel(
        &mut self,
        pending: &PendingFetch,
        timeout: std::time::Duration,
    ) -> Result<(), ResearchClientError> {
        self.supervisor.submit(WorkerRequest::Cancel {
            protocol_version: PROTOCOL_VERSION,
            request_id: pending.request_id.clone(),
        })?;
        match self.supervisor.wait_for_fetch(&pending.request_id, timeout) {
            Ok(WorkerResponse::Cancelled { .. }) => Ok(()),
            Ok(WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::NotFound,
                ..
            }) => Err(ResearchClientError::AlreadyFinished { request_id }),
            Ok(response) => Err(ResearchClientError::UnexpectedResponse {
                request_id: pending.request_id.clone(),
                response: format!("{response:?}"),
            }),
            Err(error) => Err(error.into()),
        }
    }

    pub fn shutdown(&mut self) -> Result<crate::supervisor::ShutdownOutcome, ResearchClientError> {
        Ok(self.supervisor.shutdown()?)
    }

    fn map_terminal_response(
        &self,
        pending: &PendingFetch,
        response: WorkerResponse,
    ) -> Result<ResearchSourceRecord, ResearchClientError> {
        match response {
            WorkerResponse::FetchCompleted {
                status,
                final_url,
                content_type,
                body_base64,
                redirect_count,
                ..
            } => {
                let body = crate::protocol::decode_body(&body_base64).map_err(|error| {
                    ResearchClientError::Supervisor(SupervisorError::Protocol(error.to_string()))
                })?;
                let retrieved_at_unix_ms = SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map_err(ResearchClientError::Clock)?
                    .as_millis();
                Ok(ResearchSourceRecord {
                    requested_url: pending.requested_url.clone(),
                    final_url,
                    status,
                    content_type,
                    content_hash_sha256: sha256_hex(&body),
                    body,
                    retrieved_at_unix_ms,
                    redirect_count,
                    capture_method: "swarm-research",
                })
            }
            WorkerResponse::Cancelled { .. } => Err(ResearchClientError::Cancelled {
                request_id: pending.request_id.clone(),
            }),
            WorkerResponse::Error {
                request_id: Some(request_id),
                code: WorkerErrorCode::NotFound,
                ..
            } => Err(ResearchClientError::AlreadyFinished { request_id }),
            WorkerResponse::Error {
                request_id: Some(request_id),
                code,
                message,
            } => Err(ResearchClientError::Worker {
                request_id,
                code,
                message,
            }),
            other => Err(ResearchClientError::UnexpectedResponse {
                request_id: pending.request_id.clone(),
                response: format!("{other:?}"),
            }),
        }
    }
}

fn next_request_id() -> String {
    let sequence = NEXT_REQUEST_ID.fetch_add(1, Ordering::Relaxed);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();
    format!("research-{timestamp:x}-{sequence:x}")
}

fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_is_stable_and_hex_encoded() {
        assert_eq!(
            sha256_hex(b"hello"),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn request_ids_are_nonempty_and_unique() {
        let first = next_request_id();
        let second = next_request_id();
        assert!(!first.is_empty());
        assert_ne!(first, second);
    }
}
