//! Typed, bounded NDJSON protocol for the isolated Hive research worker.
//!
//! The worker's stdout is a machine-readable stream. Diagnostics must go to
//! stderr. Each frame is one JSON object followed by `\n`; frames are consumed
//! incrementally before deserialization so malformed input cannot grow memory
//! without limit.
//!
//! `Cancel` is an intent, not a forced kill: the worker owns an active task
//! registry. A cancel that wins before completion emits `Cancelled`; a
//! completion that wins first remains valid. Cancelling an inactive or already
//! finished request returns `NotFound`; the worker does not retain terminal
//! results as an idempotency store. The standalone worker process lives in
//! `main.rs`; this module remains the reusable framing and validation boundary.

use std::fmt;
use std::io::{self, BufRead, Write};

use base64::Engine;
use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u16 = 1;
pub const DEFAULT_MAX_FRAME_BYTES: usize = 8 * 1024 * 1024;
pub const MAX_FRAME_BYTES: usize = 16 * 1024 * 1024;
pub const MAX_REQUEST_ID_BYTES: usize = 128;
pub const MAX_URL_BYTES: usize = 8 * 1024;
pub const MAX_TIMEOUT_MS: u64 = 120_000;
pub const MAX_BODY_BYTES: usize = 5 * 1024 * 1024;
pub const MAX_BODY_BASE64_BYTES: usize = ((MAX_BODY_BYTES + 2) / 3) * 4;
pub const MAX_FINAL_URL_BYTES: usize = 8 * 1024;
pub const MAX_CONTENT_TYPE_BYTES: usize = 1024;
pub const MAX_MESSAGE_BYTES: usize = 8 * 1024;

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum WorkerRequest {
    Fetch {
        protocol_version: u16,
        request_id: String,
        url: String,
        timeout_ms: u64,
        max_bytes: usize,
    },
    Cancel {
        protocol_version: u16,
        request_id: String,
    },
    Ping {
        protocol_version: u16,
        request_id: String,
    },
    Shutdown {
        protocol_version: u16,
    },
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum WorkerResponse {
    Ready {
        protocol_version: u16,
    },
    FetchStarted {
        request_id: String,
    },
    FetchCompleted {
        request_id: String,
        status: u16,
        final_url: String,
        content_type: Option<String>,
        body_base64: String,
        /// Added without a protocol-version bump; old workers deserialize as zero redirects.
        #[serde(default)]
        redirect_count: usize,
    },
    Cancelled {
        request_id: String,
    },
    Pong {
        request_id: String,
    },
    Error {
        request_id: Option<String>,
        code: WorkerErrorCode,
        message: String,
    },
    ShutdownAck,
}

#[derive(Clone, Debug, Deserialize, Serialize, Eq, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum WorkerErrorCode {
    InvalidRequest,
    FrameTooLarge,
    MalformedFrame,
    UnsupportedProtocol,
    NotFound,
    Cancelled,
    FetchFailed,
    Internal,
}

#[derive(Debug)]
pub enum ProtocolError {
    Io(io::Error),
    FrameTooLarge { size: usize, limit: usize },
    MissingDelimiter,
    EmptyFrame,
    MalformedJson(serde_json::Error),
    InvalidRequest(String),
    Serialization(serde_json::Error),
}

impl fmt::Display for ProtocolError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(error) => write!(f, "protocol I/O failed: {error}"),
            Self::FrameTooLarge { size, limit } => {
                write!(
                    f,
                    "protocol frame is too large: {size} bytes (limit {limit})"
                )
            }
            Self::MissingDelimiter => write!(f, "protocol frame is missing its newline delimiter"),
            Self::EmptyFrame => write!(f, "protocol frame is empty"),
            Self::MalformedJson(error) => write!(f, "protocol frame is not valid JSON: {error}"),
            Self::InvalidRequest(message) => write!(f, "invalid protocol request: {message}"),
            Self::Serialization(error) => {
                write!(f, "protocol response serialization failed: {error}")
            }
        }
    }
}

impl std::error::Error for ProtocolError {}

impl From<io::Error> for ProtocolError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

#[derive(Clone, Copy, Debug)]
pub struct CodecConfig {
    pub max_frame_bytes: usize,
}

impl Default for CodecConfig {
    fn default() -> Self {
        Self {
            max_frame_bytes: DEFAULT_MAX_FRAME_BYTES,
        }
    }
}

impl CodecConfig {
    pub fn validate(self) -> Result<Self, ProtocolError> {
        if self.max_frame_bytes == 0 || self.max_frame_bytes > MAX_FRAME_BYTES {
            return Err(ProtocolError::InvalidRequest(format!(
                "max_frame_bytes must be between 1 and {MAX_FRAME_BYTES}"
            )));
        }
        Ok(self)
    }
}

pub fn validate_request(request: &WorkerRequest) -> Result<(), ProtocolError> {
    let protocol_version = match request {
        WorkerRequest::Fetch {
            protocol_version, ..
        }
        | WorkerRequest::Cancel {
            protocol_version, ..
        }
        | WorkerRequest::Ping {
            protocol_version, ..
        }
        | WorkerRequest::Shutdown { protocol_version } => *protocol_version,
    };
    if protocol_version != PROTOCOL_VERSION {
        return Err(ProtocolError::InvalidRequest(format!(
            "unsupported protocol version {protocol_version}; expected {PROTOCOL_VERSION}"
        )));
    }

    match request {
        WorkerRequest::Fetch {
            request_id,
            url,
            timeout_ms,
            max_bytes,
            ..
        } => {
            validate_request_id(request_id)?;
            if url.is_empty() || url.len() > MAX_URL_BYTES || has_control(url) {
                return Err(ProtocolError::InvalidRequest(
                    "url is empty, too long, or contains control characters".to_owned(),
                ));
            }
            if *timeout_ms == 0 || *timeout_ms > MAX_TIMEOUT_MS {
                return Err(ProtocolError::InvalidRequest(format!(
                    "timeout_ms must be between 1 and {MAX_TIMEOUT_MS}"
                )));
            }
            if *max_bytes == 0 || *max_bytes > MAX_BODY_BYTES {
                return Err(ProtocolError::InvalidRequest(format!(
                    "max_bytes must be between 1 and {MAX_BODY_BYTES}"
                )));
            }
        }
        WorkerRequest::Cancel { request_id, .. } | WorkerRequest::Ping { request_id, .. } => {
            validate_request_id(request_id)?;
        }
        WorkerRequest::Shutdown { .. } => {}
    }
    Ok(())
}

fn validate_request_id(request_id: &str) -> Result<(), ProtocolError> {
    if request_id.is_empty() || request_id.len() > MAX_REQUEST_ID_BYTES || has_control(request_id) {
        return Err(ProtocolError::InvalidRequest(
            "request_id is empty, too long, or contains control characters".to_owned(),
        ));
    }
    Ok(())
}

fn has_control(value: &str) -> bool {
    value.chars().any(char::is_control)
}

/// Writes one validated request as a bounded NDJSON frame.
pub fn write_request<W: Write>(
    writer: &mut W,
    request: &WorkerRequest,
    config: CodecConfig,
) -> Result<(), ProtocolError> {
    let config = config.validate()?;
    validate_request(request)?;
    let mut frame = serde_json::to_vec(request).map_err(ProtocolError::Serialization)?;
    frame.push(b'\n');
    if frame.len() > config.max_frame_bytes {
        return Err(ProtocolError::FrameTooLarge {
            size: frame.len(),
            limit: config.max_frame_bytes,
        });
    }
    writer.write_all(&frame)?;
    writer.flush()?;
    Ok(())
}

pub fn read_request<R: BufRead>(
    reader: &mut R,
    config: CodecConfig,
) -> Result<Option<WorkerRequest>, ProtocolError> {
    let config = config.validate()?;
    let mut frame = Vec::new();
    loop {
        let available = reader.fill_buf()?;
        if available.is_empty() {
            if frame.is_empty() {
                return Ok(None);
            }
            return Err(ProtocolError::MissingDelimiter);
        }
        let newline = available.iter().position(|byte| *byte == b'\n');
        let consumed = newline.map_or(available.len(), |position| position + 1);
        let next_size = frame.len().saturating_add(consumed);
        if next_size > config.max_frame_bytes {
            return Err(ProtocolError::FrameTooLarge {
                size: next_size,
                limit: config.max_frame_bytes,
            });
        }
        frame.extend_from_slice(&available[..consumed]);
        reader.consume(consumed);
        if newline.is_none() {
            continue;
        }

        frame.pop();
        if frame.last() == Some(&b'\r') {
            frame.pop();
        }
        if frame.is_empty() {
            return Err(ProtocolError::EmptyFrame);
        }
        let request: WorkerRequest =
            serde_json::from_slice(&frame).map_err(ProtocolError::MalformedJson)?;
        validate_request(&request)?;
        return Ok(Some(request));
    }
}

#[derive(Debug, Default)]
pub struct ProtocolSession {
    ready: bool,
    closed: bool,
}

impl ProtocolSession {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn is_ready(&self) -> bool {
        self.ready
    }

    pub fn is_closed(&self) -> bool {
        self.closed
    }

    /// Accepts one validated worker response and enforces the Ready handshake.
    /// A supervisor must not process task messages from an unknown protocol
    /// version or after shutdown acknowledgement.
    pub fn accept_response(
        &mut self,
        response: WorkerResponse,
    ) -> Result<WorkerResponse, ProtocolError> {
        validate_response(&response)?;
        if self.closed {
            return Err(ProtocolError::InvalidRequest(
                "response arrived after shutdown acknowledgement".to_owned(),
            ));
        }
        match &response {
            WorkerResponse::Ready { .. } if self.ready => {
                return Err(ProtocolError::InvalidRequest(
                    "duplicate Ready response".to_owned(),
                ));
            }
            WorkerResponse::Ready { .. } => {
                self.ready = true;
            }
            WorkerResponse::ShutdownAck if !self.ready => {
                return Err(ProtocolError::InvalidRequest(
                    "worker must send Ready before ShutdownAck".to_owned(),
                ));
            }
            WorkerResponse::ShutdownAck => {
                self.closed = true;
            }
            _ if !self.ready => {
                return Err(ProtocolError::InvalidRequest(
                    "worker response arrived before Ready handshake".to_owned(),
                ));
            }
            _ => {}
        }
        Ok(response)
    }
}

pub(crate) fn read_response<R: BufRead>(
    reader: &mut R,
    config: CodecConfig,
) -> Result<Option<WorkerResponse>, ProtocolError> {
    let config = config.validate()?;
    let mut frame = Vec::new();
    loop {
        let available = reader.fill_buf()?;
        if available.is_empty() {
            if frame.is_empty() {
                return Ok(None);
            }
            return Err(ProtocolError::MissingDelimiter);
        }
        let newline = available.iter().position(|byte| *byte == b'\n');
        let consumed = newline.map_or(available.len(), |position| position + 1);
        let next_size = frame.len().saturating_add(consumed);
        if next_size > config.max_frame_bytes {
            return Err(ProtocolError::FrameTooLarge {
                size: next_size,
                limit: config.max_frame_bytes,
            });
        }
        frame.extend_from_slice(&available[..consumed]);
        reader.consume(consumed);
        if newline.is_none() {
            continue;
        }

        frame.pop();
        if frame.last() == Some(&b'\r') {
            frame.pop();
        }
        if frame.is_empty() {
            return Err(ProtocolError::EmptyFrame);
        }
        let response: WorkerResponse =
            serde_json::from_slice(&frame).map_err(ProtocolError::MalformedJson)?;
        validate_response(&response)?;
        return Ok(Some(response));
    }
}

pub fn read_response_into_session<R: BufRead>(
    reader: &mut R,
    config: CodecConfig,
    session: &mut ProtocolSession,
) -> Result<Option<WorkerResponse>, ProtocolError> {
    let response = read_response(reader, config)?;
    response
        .map(|response| session.accept_response(response))
        .transpose()
}

pub fn write_response<W: Write>(
    writer: &mut W,
    response: &WorkerResponse,
    config: CodecConfig,
) -> Result<(), ProtocolError> {
    let config = config.validate()?;
    validate_response(response)?;
    let mut frame = serde_json::to_vec(response).map_err(ProtocolError::Serialization)?;
    frame.push(b'\n');
    if frame.len() > config.max_frame_bytes {
        return Err(ProtocolError::FrameTooLarge {
            size: frame.len(),
            limit: config.max_frame_bytes,
        });
    }
    writer.write_all(&frame)?;
    writer.flush()?;
    Ok(())
}

pub fn validate_response(response: &WorkerResponse) -> Result<(), ProtocolError> {
    match response {
        WorkerResponse::Ready { protocol_version } if *protocol_version != PROTOCOL_VERSION => {
            Err(ProtocolError::InvalidRequest(format!(
                "unsupported protocol version {protocol_version}; expected {PROTOCOL_VERSION}"
            )))
        }
        WorkerResponse::FetchStarted { request_id }
        | WorkerResponse::Cancelled { request_id }
        | WorkerResponse::Pong { request_id } => validate_request_id(request_id),
        WorkerResponse::FetchCompleted {
            request_id,
            status,
            final_url,
            content_type,
            body_base64,
            ..
        } => {
            validate_request_id(request_id)?;
            if final_url.is_empty()
                || final_url.len() > MAX_FINAL_URL_BYTES
                || has_control(final_url)
            {
                return Err(ProtocolError::InvalidRequest(
                    "final_url is empty, too long, or contains control characters".to_owned(),
                ));
            }
            let parsed = url::Url::parse(final_url).map_err(|error| {
                ProtocolError::InvalidRequest(format!("final_url is invalid: {error}"))
            })?;
            if !matches!(parsed.scheme(), "http" | "https")
                || parsed.host_str().is_none()
                || parsed.username() != ""
                || parsed.password().is_some()
            {
                return Err(ProtocolError::InvalidRequest(
                    "final_url must be an HTTP(S) URL without credentials".to_owned(),
                ));
            }
            if !(200..=599).contains(status) {
                return Err(ProtocolError::InvalidRequest(
                    "status must be an HTTP final status between 200 and 599".to_owned(),
                ));
            }
            if let Some(content_type) = content_type {
                if content_type.len() > MAX_CONTENT_TYPE_BYTES || has_control(content_type) {
                    return Err(ProtocolError::InvalidRequest(
                        "content_type is too long or contains control characters".to_owned(),
                    ));
                }
            }
            if body_base64.len() > MAX_BODY_BASE64_BYTES {
                return Err(ProtocolError::InvalidRequest(
                    "encoded response body exceeds the maximum size".to_owned(),
                ));
            }
            let decoded = decode_body(body_base64)?;
            if decoded.len() > MAX_BODY_BYTES {
                return Err(ProtocolError::InvalidRequest(
                    "decoded response body exceeds the maximum size".to_owned(),
                ));
            }
            Ok(())
        }
        WorkerResponse::Error {
            request_id,
            message,
            ..
        } => {
            if let Some(request_id) = request_id {
                validate_request_id(request_id)?;
            }
            if message.is_empty() || message.len() > MAX_MESSAGE_BYTES || has_control(message) {
                return Err(ProtocolError::InvalidRequest(
                    "error message is empty, too long, or contains control characters".to_owned(),
                ));
            }
            Ok(())
        }
        WorkerResponse::Ready { .. } | WorkerResponse::ShutdownAck => Ok(()),
    }
}

pub fn encode_body(body: &[u8]) -> String {
    base64::engine::general_purpose::STANDARD.encode(body)
}

pub fn decode_body(body_base64: &str) -> Result<Vec<u8>, ProtocolError> {
    base64::engine::general_purpose::STANDARD
        .decode(body_base64)
        .map_err(|error| ProtocolError::InvalidRequest(format!("body_base64 is invalid: {error}")))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufReader, Cursor};

    fn config() -> CodecConfig {
        CodecConfig {
            max_frame_bytes: 1024,
        }
    }

    fn fetch_request(request_id: &str) -> WorkerRequest {
        WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: request_id.to_owned(),
            url: "https://example.com/research".to_owned(),
            timeout_ms: 15_000,
            max_bytes: 1024,
        }
    }

    fn wire(request: &WorkerRequest) -> Vec<u8> {
        let mut encoded = serde_json::to_vec(request).unwrap();
        encoded.push(b'\n');
        encoded
    }

    #[test]
    fn request_writer_emits_one_validated_ndjson_frame() {
        let request = fetch_request("req-write");
        let mut encoded = Vec::new();
        write_request(&mut encoded, &request, config()).unwrap();
        assert_eq!(encoded.last(), Some(&b'\n'));
        let mut reader = BufReader::new(Cursor::new(encoded));
        assert_eq!(read_request(&mut reader, config()).unwrap(), Some(request));
    }

    #[test]
    fn request_round_trips_as_one_ndjson_frame() {
        let request = fetch_request("req-1");
        let mut reader = BufReader::new(Cursor::new(wire(&request)));
        assert_eq!(read_request(&mut reader, config()).unwrap(), Some(request));
    }

    #[test]
    fn additive_redirect_count_defaults_for_protocol_v1_wire_frames() {
        let frame = br#"{"type":"fetch_completed","request_id":"legacy","status":200,"final_url":"https://example.com","content_type":null,"body_base64":"b2s="}"#;
        let response: WorkerResponse = serde_json::from_slice(frame).unwrap();
        assert_eq!(
            response,
            WorkerResponse::FetchCompleted {
                request_id: "legacy".to_owned(),
                status: 200,
                final_url: "https://example.com".to_owned(),
                content_type: None,
                body_base64: "b2s=".to_owned(),
                redirect_count: 0,
            }
        );
    }

    #[test]
    fn response_version_and_request_ids_are_validated() {
        assert!(validate_response(&WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        })
        .is_ok());
        assert!(matches!(
            validate_response(&WorkerResponse::Ready {
                protocol_version: PROTOCOL_VERSION + 1,
            }),
            Err(ProtocolError::InvalidRequest(message)) if message.contains("version")
        ));
        assert!(validate_response(&WorkerResponse::Pong {
            request_id: "req-1".to_owned(),
        })
        .is_ok());
        assert!(validate_response(&WorkerResponse::Pong {
            request_id: "bad\nrequest".to_owned(),
        })
        .is_err());
    }

    #[test]
    fn response_is_newline_delimited_and_flushable() {
        let mut wire = Vec::new();
        write_response(
            &mut wire,
            &WorkerResponse::Ready {
                protocol_version: PROTOCOL_VERSION,
            },
            config(),
        )
        .unwrap();
        assert_eq!(wire.last(), Some(&b'\n'));
        assert_eq!(wire.iter().filter(|byte| **byte == b'\n').count(), 1);
    }

    #[test]
    fn rejects_missing_delimiter_empty_and_oversized_frames_incrementally() {
        let mut missing = BufReader::new(Cursor::new(br#"{"type":"shutdown"}"#.to_vec()));
        assert!(matches!(
            read_request(&mut missing, config()),
            Err(ProtocolError::MissingDelimiter)
        ));
        let mut empty = BufReader::new(Cursor::new(b"\n".to_vec()));
        assert!(matches!(
            read_request(&mut empty, config()),
            Err(ProtocolError::EmptyFrame)
        ));
        let mut oversized = BufReader::new(Cursor::new(vec![b'x'; 1025]));
        assert!(matches!(
            read_request(&mut oversized, config()),
            Err(ProtocolError::FrameTooLarge { .. })
        ));
    }

    #[test]
    fn rejects_unbounded_config_and_invalid_version() {
        assert!(CodecConfig {
            max_frame_bytes: MAX_FRAME_BYTES + 1
        }
        .validate()
        .is_err());
        let invalid = WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION + 1,
            request_id: "a".to_owned(),
            url: "https://example.com/research".to_owned(),
            timeout_ms: 15_000,
            max_bytes: 1024,
        };
        assert!(matches!(
            validate_request(&invalid),
            Err(ProtocolError::InvalidRequest(message)) if message.contains("version")
        ));
    }

    #[test]
    fn rejects_malformed_and_invalid_requests() {
        let mut malformed = BufReader::new(Cursor::new(b"not-json\n".to_vec()));
        assert!(matches!(
            read_request(&mut malformed, config()),
            Err(ProtocolError::MalformedJson(_))
        ));
        let invalid = WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: "req\n1".to_owned(),
            url: "https://example.com".to_owned(),
            timeout_ms: 1000,
            max_bytes: 100,
        };
        assert!(matches!(
            validate_request(&invalid),
            Err(ProtocolError::InvalidRequest(_))
        ));
    }

    #[test]
    fn accepts_cancel_ping_and_shutdown() {
        let requests = [
            WorkerRequest::Cancel {
                protocol_version: PROTOCOL_VERSION,
                request_id: "a".to_owned(),
            },
            WorkerRequest::Ping {
                protocol_version: PROTOCOL_VERSION,
                request_id: "b".to_owned(),
            },
            WorkerRequest::Shutdown {
                protocol_version: PROTOCOL_VERSION,
            },
        ];
        for request in requests {
            let mut reader = BufReader::new(Cursor::new(wire(&request)));
            assert_eq!(read_request(&mut reader, config()).unwrap(), Some(request));
        }
    }

    #[test]
    fn validates_timeout_and_body_bounds() {
        let zero_timeout = WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: "a".to_owned(),
            url: "https://example.com".to_owned(),
            timeout_ms: 0,
            max_bytes: 1,
        };
        assert!(validate_request(&zero_timeout).is_err());
        let too_large = WorkerRequest::Fetch {
            protocol_version: PROTOCOL_VERSION,
            request_id: "a".to_owned(),
            url: "https://example.com".to_owned(),
            timeout_ms: 1,
            max_bytes: MAX_BODY_BYTES + 1,
        };
        assert!(validate_request(&too_large).is_err());
    }

    #[test]
    fn body_encoding_round_trips_binary_bytes() {
        let original = [0, 1, 2, 127, 128, 254, 255];
        let encoded = encode_body(&original);
        assert_eq!(decode_body(&encoded).unwrap(), original);
    }

    #[test]
    fn rejects_invalid_response_metadata_and_body() {
        let invalid_url = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 200,
            final_url: "file:///tmp/secret".to_owned(),
            content_type: None,
            body_base64: encode_body(b"ok"),
            redirect_count: 0,
        };
        assert!(validate_response(&invalid_url).is_err());

        let hostless_url = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 200,
            final_url: "https://".to_owned(),
            content_type: None,
            body_base64: encode_body(b"ok"),
            redirect_count: 0,
        };
        assert!(validate_response(&hostless_url).is_err());

        let invalid_body = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 200,
            final_url: "https://example.com".to_owned(),
            content_type: None,
            body_base64: "not base64".to_owned(),
            redirect_count: 0,
        };
        assert!(validate_response(&invalid_body).is_err());

        let oversized_body = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 200,
            final_url: "https://example.com".to_owned(),
            content_type: None,
            body_base64: "A".repeat(MAX_BODY_BASE64_BYTES + 1),
            redirect_count: 0,
        };
        assert!(validate_response(&oversized_body).is_err());

        let invalid_message = WorkerResponse::Error {
            request_id: None,
            code: WorkerErrorCode::Internal,
            message: "\n".to_owned(),
        };
        assert!(validate_response(&invalid_message).is_err());
    }

    #[test]
    fn response_reader_applies_the_same_bounds_and_validation() {
        let response = WorkerResponse::Ready {
            protocol_version: PROTOCOL_VERSION,
        };
        let mut encoded = serde_json::to_vec(&response).unwrap();
        encoded.push(b'\n');
        let mut reader = BufReader::new(Cursor::new(encoded));
        assert_eq!(
            read_response(&mut reader, config()).unwrap(),
            Some(response)
        );

        let mut malformed = BufReader::new(Cursor::new(b"not-json\n".to_vec()));
        assert!(matches!(
            read_response(&mut malformed, config()),
            Err(ProtocolError::MalformedJson(_))
        ));

        let mut oversized = BufReader::new(Cursor::new(vec![b'x'; 1025]));
        assert!(matches!(
            read_response(&mut oversized, config()),
            Err(ProtocolError::FrameTooLarge { .. })
        ));
    }

    #[test]
    fn session_requires_ready_and_closes_after_shutdown() {
        let mut session = ProtocolSession::new();

        let mut before_ready = BufReader::new(Cursor::new(
            serde_json::to_vec(&WorkerResponse::Pong {
                request_id: "req".to_owned(),
            })
            .unwrap()
            .into_iter()
            .chain(std::iter::once(b'\n'))
            .collect::<Vec<_>>(),
        ));
        assert!(read_response_into_session(&mut before_ready, config(), &mut session).is_err());
        assert!(!session.is_ready());

        let mut ready = BufReader::new(Cursor::new(
            serde_json::to_vec(&WorkerResponse::Ready {
                protocol_version: PROTOCOL_VERSION,
            })
            .unwrap()
            .into_iter()
            .chain(std::iter::once(b'\n'))
            .collect::<Vec<_>>(),
        ));
        assert!(read_response_into_session(&mut ready, config(), &mut session).is_ok());
        assert!(session.is_ready());

        let mut shutdown = BufReader::new(Cursor::new(b"{\"type\":\"shutdown_ack\"}\n".to_vec()));
        assert!(read_response_into_session(&mut shutdown, config(), &mut session).is_ok());
        assert!(session.is_closed());

        let mut after_shutdown = BufReader::new(Cursor::new(
            serde_json::to_vec(&WorkerResponse::Pong {
                request_id: "req".to_owned(),
            })
            .unwrap()
            .into_iter()
            .chain(std::iter::once(b'\n'))
            .collect::<Vec<_>>(),
        ));
        assert!(read_response_into_session(&mut after_shutdown, config(), &mut session).is_err());
    }

    #[test]
    fn rejects_duplicate_ready_and_shutdown_before_ready() {
        let mut duplicate = ProtocolSession::new();
        assert!(duplicate
            .accept_response(WorkerResponse::Ready {
                protocol_version: PROTOCOL_VERSION,
            })
            .is_ok());
        assert!(duplicate
            .accept_response(WorkerResponse::Ready {
                protocol_version: PROTOCOL_VERSION,
            })
            .is_err());

        let mut before_ready = ProtocolSession::new();
        assert!(before_ready
            .accept_response(WorkerResponse::ShutdownAck)
            .is_err());
    }

    #[test]
    fn rejects_invalid_status_codes() {
        let response = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 600,
            final_url: "https://example.com".to_owned(),
            content_type: None,
            body_base64: encode_body(b"ok"),
            redirect_count: 0,
        };
        assert!(validate_response(&response).is_err());
    }

    #[test]
    fn response_frame_limit_is_checked_before_write() {
        let response = WorkerResponse::FetchCompleted {
            request_id: "request".to_owned(),
            status: 200,
            final_url: "https://example.com".to_owned(),
            content_type: None,
            body_base64: encode_body(&vec![0_u8; 2000]),
            redirect_count: 0,
        };
        let mut wire = Vec::new();
        assert!(matches!(
            write_response(&mut wire, &response, config()),
            Err(ProtocolError::FrameTooLarge { .. })
        ));
    }
}
