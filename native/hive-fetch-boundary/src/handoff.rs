//! Versioned JSON handoff from the Rust research boundary to a future
//! application/Honeycomb adapter.
//!
//! This is deliberately not an FFI ABI and does not persist anything. It is a
//! bounded, self-describing document that can cross a later process boundary
//! without leaking an internal Rust struct or claiming that extraction and
//! citation grounding already happened.

use std::fmt;

use base64::Engine;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use url::Url;

use crate::protocol::{MAX_BODY_BASE64_BYTES, MAX_BODY_BYTES, MAX_FINAL_URL_BYTES, MAX_URL_BYTES};
use crate::research_client::ResearchSourceRecord;

pub const HANDOFF_SCHEMA_VERSION: u16 = 1;
pub const MAX_HANDOFF_JSON_BYTES: usize = 8 * 1024 * 1024;
pub const MAX_CAPTURE_METHOD_BYTES: usize = 128;
pub const MAX_PROVENANCE_VALUE_BYTES: usize = 256;
pub const MAX_REDIRECT_COUNT: usize = 64;

/// The top-level document kind. A string keeps the wire format extensible while
/// validation prevents this module from silently accepting another document.
pub const RESEARCH_SOURCE_HANDOFF_KIND: &str = "research_source";

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum RetentionClass {
    /// Delete after the current operation unless a caller explicitly promotes it.
    Ephemeral,
    /// Keep while the current browser session is active.
    Session,
    /// Keep as project knowledge until the user deletes or changes policy.
    Project,
    /// Keep until explicit user deletion. This is never selected implicitly by
    /// `from_record`.
    Permanent,
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DeletionScope {
    /// Delete only this handoff/source payload.
    ThisSource,
    /// Delete this source and records sharing its capture provenance.
    Provenance,
    /// Delete this source as part of the owning project. Project association is
    /// intentionally not invented by this transport-only envelope.
    Project,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct RetentionPolicy {
    pub class: RetentionClass,
    pub deletion_scope: DeletionScope,
    /// Unix milliseconds as a decimal string. `None` means policy-driven
    /// deletion rather than a timestamp supplied by the transport boundary.
    /// Strings avoid precision loss in JavaScript and other JSON consumers.
    #[serde(default, deserialize_with = "deserialize_optional_decimal_string")]
    pub expires_at_unix_ms: Option<String>,
}

impl Default for RetentionPolicy {
    fn default() -> Self {
        Self {
            class: RetentionClass::Session,
            deletion_scope: DeletionScope::ThisSource,
            expires_at_unix_ms: None,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ExtractionState {
    /// The body is retained as fetched bytes; no HTML/text extraction occurred.
    NotExtracted,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct HandoffSource {
    pub requested_url: String,
    pub final_url: String,
    pub status: u16,
    pub content_type: Option<String>,
    pub redirect_count: usize,
    /// Unix milliseconds as a decimal string. The internal client record uses
    /// `u128`; decimal text preserves the exact value across JSON consumers.
    #[serde(deserialize_with = "deserialize_decimal_string")]
    pub retrieved_at_unix_ms: String,
    pub content_hash_sha256: String,
    pub body_base64: String,
    pub capture_method: String,
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ResearchSourceHandoff {
    pub schema_version: u16,
    pub kind: String,
    /// Stable origin label for the record. This is metadata only; it does not
    /// grant trust to page content or authorize model/tool use. The default
    /// keeps already-emitted schema-v1 envelopes readable.
    #[serde(default = "default_provenance")]
    pub provenance: String,
    pub source: HandoffSource,
    pub retention: RetentionPolicy,
    pub extraction: ExtractionState,
    /// Explicitly false at this boundary: citations require extracted spans and
    /// Honeycomb source/claim edges, neither of which this envelope creates.
    pub citation_ready: bool,
}

#[derive(Debug)]
pub enum HandoffError {
    PayloadTooLarge { size: usize, limit: usize },
    Serialization(serde_json::Error),
    InvalidJson(serde_json::Error),
    UnsupportedSchema(u16),
    InvalidField(String),
}

impl fmt::Display for HandoffError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::PayloadTooLarge { size, limit } => {
                write!(
                    f,
                    "research handoff is too large: {size} bytes (limit {limit})"
                )
            }
            Self::Serialization(error) => {
                write!(f, "research handoff serialization failed: {error}")
            }
            Self::InvalidJson(error) => write!(f, "research handoff JSON is invalid: {error}"),
            Self::UnsupportedSchema(version) => {
                write!(f, "unsupported research handoff schema version: {version}")
            }
            Self::InvalidField(message) => write!(f, "invalid research handoff field: {message}"),
        }
    }
}

impl std::error::Error for HandoffError {}

impl ResearchSourceHandoff {
    /// Builds the transport envelope with conservative defaults. The raw
    /// fetch result is marked session-retained, source-scoped, unextracted, and
    /// not citation-ready until an application layer changes that policy after
    /// user intent and actual processing.
    pub fn from_record(record: &ResearchSourceRecord) -> Result<Self, HandoffError> {
        let envelope = Self {
            schema_version: HANDOFF_SCHEMA_VERSION,
            kind: RESEARCH_SOURCE_HANDOFF_KIND.to_owned(),
            provenance: "rust-research-boundary".to_owned(),
            source: HandoffSource {
                requested_url: record.requested_url.clone(),
                final_url: record.final_url.clone(),
                status: record.status,
                content_type: record.content_type.clone(),
                redirect_count: record.redirect_count,
                retrieved_at_unix_ms: record.retrieved_at_unix_ms.to_string(),
                content_hash_sha256: record.content_hash_sha256.clone(),
                body_base64: base64::engine::general_purpose::STANDARD.encode(&record.body),
                capture_method: record.capture_method.to_owned(),
            },
            retention: RetentionPolicy::default(),
            extraction: ExtractionState::NotExtracted,
            citation_ready: false,
        };
        envelope.validate()?;
        Ok(envelope)
    }

    pub fn with_retention(mut self, retention: RetentionPolicy) -> Result<Self, HandoffError> {
        self.retention = retention;
        self.validate()?;
        Ok(self)
    }

    /// Validates both the semantic fields and the body/hash integrity. This is
    /// required after deserialization and before handing data to persistence or
    /// a model context broker.
    pub fn validate(&self) -> Result<(), HandoffError> {
        if self.schema_version != HANDOFF_SCHEMA_VERSION {
            return Err(HandoffError::UnsupportedSchema(self.schema_version));
        }
        if self.kind != RESEARCH_SOURCE_HANDOFF_KIND {
            return Err(HandoffError::InvalidField(
                "kind is not research_source".to_owned(),
            ));
        }
        validate_bounded_text(&self.provenance, MAX_PROVENANCE_VALUE_BYTES, "provenance")?;
        validate_url(&self.source.requested_url, "requested_url")?;
        validate_url(&self.source.final_url, "final_url")?;
        if !(200..=599).contains(&self.source.status) {
            return Err(HandoffError::InvalidField(
                "status must be between 200 and 599".to_owned(),
            ));
        }
        if self.source.redirect_count > MAX_REDIRECT_COUNT {
            return Err(HandoffError::InvalidField(
                "redirect_count exceeds the handoff limit".to_owned(),
            ));
        }
        if let Some(content_type) = &self.source.content_type {
            validate_bounded_text(content_type, 1024, "content_type")?;
        }
        validate_bounded_text(
            &self.source.capture_method,
            MAX_CAPTURE_METHOD_BYTES,
            "capture_method",
        )?;
        validate_bounded_text(&self.source.content_hash_sha256, 64, "content_hash_sha256")?;
        if self.source.content_hash_sha256.len() != 64
            || !self
                .source
                .content_hash_sha256
                .chars()
                .all(|character| character.is_ascii_hexdigit())
        {
            return Err(HandoffError::InvalidField(
                "content_hash_sha256 must be 64 hexadecimal characters".to_owned(),
            ));
        }
        if self.source.body_base64.len() > MAX_BODY_BASE64_BYTES {
            return Err(HandoffError::InvalidField(
                "body_base64 exceeds the maximum encoded body size".to_owned(),
            ));
        }
        validate_positive_decimal(&self.source.retrieved_at_unix_ms, "retrieved_at_unix_ms")?;
        let body = base64::engine::general_purpose::STANDARD
            .decode(&self.source.body_base64)
            .map_err(|error| {
                HandoffError::InvalidField(format!("body_base64 is invalid: {error}"))
            })?;
        if body.len() > MAX_BODY_BYTES {
            return Err(HandoffError::InvalidField(
                "decoded body exceeds the maximum body size".to_owned(),
            ));
        }
        let actual_hash = sha256_hex(&body);
        if actual_hash != self.source.content_hash_sha256 {
            return Err(HandoffError::InvalidField(
                "content_hash_sha256 does not match body_base64".to_owned(),
            ));
        }
        if let Some(expiration) = &self.retention.expires_at_unix_ms {
            validate_positive_decimal(expiration, "expires_at_unix_ms")?;
        }
        if self.extraction != ExtractionState::NotExtracted || self.citation_ready {
            return Err(HandoffError::InvalidField(
                "raw transport handoffs cannot claim extraction or citation readiness".to_owned(),
            ));
        }
        Ok(())
    }

    /// Serializes one validated, bounded document. JSON is the handoff format;
    /// it is not a storage format and has no implicit persistence side effects.
    pub fn to_json_bytes(&self) -> Result<Vec<u8>, HandoffError> {
        self.validate()?;
        let encoded = serde_json::to_vec(self).map_err(HandoffError::Serialization)?;
        if encoded.len() > MAX_HANDOFF_JSON_BYTES {
            return Err(HandoffError::PayloadTooLarge {
                size: encoded.len(),
                limit: MAX_HANDOFF_JSON_BYTES,
            });
        }
        Ok(encoded)
    }

    /// Parses only bounded input, then applies the same semantic and integrity
    /// checks as a locally-created envelope. Serde intentionally ignores unknown
    /// additive fields for forward compatibility.
    pub fn from_json_bytes(bytes: &[u8]) -> Result<Self, HandoffError> {
        if bytes.len() > MAX_HANDOFF_JSON_BYTES {
            return Err(HandoffError::PayloadTooLarge {
                size: bytes.len(),
                limit: MAX_HANDOFF_JSON_BYTES,
            });
        }
        let envelope: Self = serde_json::from_slice(bytes).map_err(HandoffError::InvalidJson)?;
        envelope.validate()?;
        Ok(envelope)
    }
}

fn default_provenance() -> String {
    "legacy-v1".to_owned()
}

fn validate_positive_decimal(value: &str, field: &str) -> Result<(), HandoffError> {
    let parsed = value.parse::<u128>().map_err(|_| {
        HandoffError::InvalidField(format!(
            "{field} must be a positive canonical decimal string"
        ))
    })?;
    if parsed == 0 || parsed.to_string() != value {
        return Err(HandoffError::InvalidField(format!(
            "{field} must be a positive canonical decimal string"
        )));
    }
    Ok(())
}

fn deserialize_decimal_string<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        serde_json::Value::String(value)
            if value.chars().all(|character| character.is_ascii_digit()) =>
        {
            Ok(value)
        }
        serde_json::Value::Number(value) => Ok(value.to_string()),
        _ => Err(serde::de::Error::custom(
            "expected a decimal string or JSON number",
        )),
    }
}

fn deserialize_optional_decimal_string<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = Option::<serde_json::Value>::deserialize(deserializer)?;
    match value {
        None | Some(serde_json::Value::Null) => Ok(None),
        Some(serde_json::Value::String(value))
            if value.chars().all(|character| character.is_ascii_digit()) =>
        {
            Ok(Some(value))
        }
        Some(serde_json::Value::Number(value)) => Ok(Some(value.to_string())),
        _ => Err(serde::de::Error::custom(
            "expected an optional decimal string or JSON number",
        )),
    }
}

fn validate_url(value: &str, field: &str) -> Result<(), HandoffError> {
    let max_bytes = if field == "requested_url" {
        MAX_URL_BYTES
    } else {
        MAX_FINAL_URL_BYTES
    };
    if value.is_empty() || value.len() > max_bytes || value.chars().any(char::is_control) {
        return Err(HandoffError::InvalidField(format!(
            "{field} is empty, too long, or contains control characters"
        )));
    }
    let parsed = Url::parse(value).map_err(|error| {
        HandoffError::InvalidField(format!("{field} is not a valid URL: {error}"))
    })?;
    if !matches!(parsed.scheme(), "http" | "https")
        || parsed.host_str().is_none()
        || !parsed.username().is_empty()
        || parsed.password().is_some()
    {
        return Err(HandoffError::InvalidField(format!(
            "{field} must be an HTTP(S) URL without credentials"
        )));
    }
    Ok(())
}

fn validate_bounded_text(value: &str, max_bytes: usize, field: &str) -> Result<(), HandoffError> {
    if value.is_empty() || value.len() > max_bytes || value.chars().any(char::is_control) {
        return Err(HandoffError::InvalidField(format!(
            "{field} is empty, too long, or contains control characters"
        )));
    }
    Ok(())
}

fn sha256_hex(bytes: &[u8]) -> String {
    Sha256::digest(bytes)
        .iter()
        .map(|byte| format!("{byte:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record() -> ResearchSourceRecord {
        let body = b"<html>raw fixture</html>".to_vec();
        ResearchSourceRecord {
            requested_url: "https://example.com/start".to_owned(),
            final_url: "https://example.com/final".to_owned(),
            status: 200,
            content_type: Some("text/html".to_owned()),
            content_hash_sha256: sha256_hex(&body),
            body,
            retrieved_at_unix_ms: 1_725_000_000_000,
            redirect_count: 1,
            capture_method: "swarm-research",
        }
    }

    #[test]
    fn record_round_trips_with_provenance_and_integrity() {
        let handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        let bytes = handoff.to_json_bytes().unwrap();
        let decoded = ResearchSourceHandoff::from_json_bytes(&bytes).unwrap();
        assert_eq!(decoded, handoff);
        assert_eq!(decoded.source.requested_url, "https://example.com/start");
        assert_eq!(decoded.source.final_url, "https://example.com/final");
        assert_eq!(decoded.source.redirect_count, 1);
        assert!(!decoded.citation_ready);
        assert_eq!(decoded.extraction, ExtractionState::NotExtracted);
    }

    #[test]
    fn retention_policy_is_explicit_and_round_trips() {
        let handoff = ResearchSourceHandoff::from_record(&record())
            .unwrap()
            .with_retention(RetentionPolicy {
                class: RetentionClass::Project,
                deletion_scope: DeletionScope::Provenance,
                expires_at_unix_ms: Some("1800000000000".to_owned()),
            })
            .unwrap();
        let decoded =
            ResearchSourceHandoff::from_json_bytes(&handoff.to_json_bytes().unwrap()).unwrap();
        assert_eq!(decoded.retention.class, RetentionClass::Project);
        assert_eq!(decoded.retention.deletion_scope, DeletionScope::Provenance);
        assert_eq!(
            decoded.retention.expires_at_unix_ms,
            Some("1800000000000".to_owned())
        );
    }

    #[test]
    fn rejects_hash_mismatch_and_invalid_base64() {
        let mut handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.content_hash_sha256 = "0".repeat(64);
        assert!(
            matches!(handoff.validate(), Err(HandoffError::InvalidField(message)) if message.contains("does not match"))
        );
        handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.body_base64 = "not base64".to_owned();
        assert!(
            matches!(handoff.validate(), Err(HandoffError::InvalidField(message)) if message.contains("body_base64"))
        );
    }

    #[test]
    fn rejects_unsupported_schema_wrong_kind_and_claims() {
        let mut handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.schema_version = HANDOFF_SCHEMA_VERSION + 1;
        assert!(matches!(
            handoff.validate(),
            Err(HandoffError::UnsupportedSchema(_))
        ));
        handoff.schema_version = HANDOFF_SCHEMA_VERSION;
        handoff.kind = "other_document".to_owned();
        assert!(
            matches!(handoff.validate(), Err(HandoffError::InvalidField(message)) if message.contains("kind"))
        );
        handoff.kind = RESEARCH_SOURCE_HANDOFF_KIND.to_owned();
        handoff.provenance = "bad\nprovenance".to_owned();
        assert!(
            matches!(handoff.validate(), Err(HandoffError::InvalidField(message)) if message.contains("provenance"))
        );
        handoff.provenance = "rust-research-boundary".to_owned();
        handoff.citation_ready = true;
        assert!(
            matches!(handoff.validate(), Err(HandoffError::InvalidField(message)) if message.contains("citation"))
        );
    }

    #[test]
    fn rejects_credentials_controls_and_invalid_status() {
        let mut handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.final_url = "https://user:password@example.com".to_owned();
        assert!(handoff.validate().is_err());
        handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.status = 600;
        assert!(handoff.validate().is_err());
        handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.capture_method = "bad\nmethod".to_owned();
        assert!(handoff.validate().is_err());
        handoff.source.retrieved_at_unix_ms = "not-a-number".to_owned();
        assert!(handoff.validate().is_err());
        handoff.source.retrieved_at_unix_ms = "00".to_owned();
        assert!(handoff.validate().is_err());
        handoff.source.retrieved_at_unix_ms = "0001".to_owned();
        assert!(handoff.validate().is_err());
    }

    #[test]
    fn accepts_legacy_v1_without_provenance_and_numeric_timestamp() {
        let handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        let mut value: serde_json::Value =
            serde_json::from_slice(&handoff.to_json_bytes().unwrap()).unwrap();
        value.as_object_mut().unwrap().remove("provenance");
        value["source"]["retrieved_at_unix_ms"] = serde_json::json!(1725000000000_u64);
        let decoded =
            ResearchSourceHandoff::from_json_bytes(&serde_json::to_vec(&value).unwrap()).unwrap();
        assert_eq!(decoded.provenance, "legacy-v1");
        assert_eq!(decoded.source.retrieved_at_unix_ms, "1725000000000");
    }

    #[test]
    fn accepts_unknown_additive_json_fields() {
        let handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        let mut value: serde_json::Value =
            serde_json::from_slice(&handoff.to_json_bytes().unwrap()).unwrap();
        value["future_field"] = serde_json::json!({"reserved": true});
        value["source"]["future_source_field"] = serde_json::json!("ignored");
        let decoded =
            ResearchSourceHandoff::from_json_bytes(&serde_json::to_vec(&value).unwrap()).unwrap();
        assert_eq!(decoded, handoff);
    }

    #[test]
    fn rejects_oversized_json_before_deserialization() {
        let oversized = vec![b' '; MAX_HANDOFF_JSON_BYTES + 1];
        assert!(matches!(
            ResearchSourceHandoff::from_json_bytes(&oversized),
            Err(HandoffError::PayloadTooLarge { .. })
        ));
    }

    #[test]
    fn rejects_expiration_zero_and_redirect_overflow() {
        let mut handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.retention.expires_at_unix_ms = Some("0".to_owned());
        assert!(handoff.validate().is_err());
        handoff.retention.expires_at_unix_ms = Some("00".to_owned());
        assert!(handoff.validate().is_err());
        handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.redirect_count = MAX_REDIRECT_COUNT + 1;
        assert!(handoff.validate().is_err());
    }

    #[test]
    fn preserves_large_timestamps_and_rejects_oversized_urls() {
        let mut source = record();
        source.retrieved_at_unix_ms = u128::MAX;
        let handoff = ResearchSourceHandoff::from_record(&source).unwrap();
        assert_eq!(handoff.source.retrieved_at_unix_ms, u128::MAX.to_string());

        let mut handoff = ResearchSourceHandoff::from_record(&record()).unwrap();
        handoff.source.requested_url = format!("https://example.com/{}", "x".repeat(MAX_URL_BYTES));
        assert!(handoff.validate().is_err());
        handoff.source.requested_url = "https://example.com/start".to_owned();
        handoff.source.final_url =
            format!("https://example.com/{}", "x".repeat(MAX_FINAL_URL_BYTES));
        assert!(handoff.validate().is_err());
    }
}
