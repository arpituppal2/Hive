//! Hive's cross-platform research fetch boundary.
//!
//! This crate provides an SSRF-aware TCP and HTTPS research boundary. It
//! resolves a hostname, rejects unsafe destinations, connects to one of the
//! approved addresses, and uses the original hostname for HTTP authority and
//! TLS SNI. Redirects are manual, cookies are absent, and response bodies are
//! bounded. HTML extraction and browser IPC remain outside this crate.
//!
//! The important security property is that callers do not resolve a hostname
//! once and then hand the hostname back to a high-level client that may resolve
//! it again. `ResolutionPlan::connect` connects only to addresses already
//! validated by the plan. The caller must use `ResolutionPlan::hostname()` for
//! HTTP authority and TLS server-name configuration.

use std::fmt;
use std::io::{self, Read, Write};
use std::net::{IpAddr, SocketAddr, TcpStream, ToSocketAddrs};
use std::sync::Arc;
use std::time::{Duration, Instant};

use rustls::{ClientConfig, ClientConnection, RootCertStore, StreamOwned};
use url::Url;

pub mod handoff;
pub mod protocol;
pub mod research_client;
pub mod supervisor;

/// A hostname and service destination, kept separate from the chosen socket
/// address so HTTP authority and TLS SNI can remain the original hostname.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct HostTarget {
    hostname: String,
    port: u16,
}

impl HostTarget {
    /// Creates a target for a DNS name or IP literal.
    pub fn new(hostname: impl Into<String>, port: u16) -> Result<Self, ResolveError> {
        let hostname = hostname.into();
        validate_hostname(&hostname)?;
        if let Some(literal) = parse_ip_literal(&hostname) {
            if !is_allowed_ip(literal) {
                return Err(ResolveError::UnsafeAddress { address: literal });
            }
        }
        Ok(Self { hostname, port })
    }

    pub fn hostname(&self) -> &str {
        &self.hostname
    }

    pub fn port(&self) -> u16 {
        self.port
    }
}

/// The reason a destination was rejected before a socket was opened.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ResolveError {
    EmptyHostname,
    InvalidHostname(String),
    NoAddresses { hostname: String, port: u16 },
    PortMismatch { expected: u16, actual: u16 },
    UnsafeAddress { address: IpAddr },
    Resolver(io::ErrorKind),
}

impl fmt::Display for ResolveError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyHostname => write!(f, "hostname is empty"),
            Self::InvalidHostname(hostname) => write!(f, "invalid hostname: {hostname}"),
            Self::NoAddresses { hostname, port } => {
                write!(f, "no addresses resolved for {hostname}:{port}")
            }
            Self::PortMismatch { expected, actual } => {
                write!(
                    f,
                    "resolved port {actual} does not match target port {expected}"
                )
            }
            Self::UnsafeAddress { address } => {
                write!(f, "resolved address is private or reserved: {address}")
            }
            Self::Resolver(kind) => write!(f, "hostname resolution failed: {kind:?}"),
        }
    }
}

impl std::error::Error for ResolveError {}

/// A validated set of addresses for one original host target.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ResolutionPlan {
    target: HostTarget,
    addresses: Vec<SocketAddr>,
}

impl ResolutionPlan {
    /// Resolves using the synchronous platform resolver and rejects the entire
    /// result if any answer is unsafe. Run this from a blocking worker, not a
    /// UI thread or async executor. Failing closed avoids selecting a public
    /// answer from a mixed response that also contains a private address.
    pub fn resolve(hostname: impl Into<String>, port: u16) -> Result<Self, ResolveError> {
        let target = HostTarget::new(hostname, port)?;
        let lookup_hostname = target
            .hostname
            .strip_prefix('[')
            .and_then(|value| value.strip_suffix(']'))
            .unwrap_or(target.hostname.as_str());
        let lookup = (lookup_hostname, target.port)
            .to_socket_addrs()
            .map_err(|error| ResolveError::Resolver(error.kind()))?;
        Self::from_addresses(target, lookup)
    }

    /// Builds a plan from already-resolved addresses. This is an internal
    /// deterministic seam used by the platform resolver and unit tests only;
    /// it is intentionally not public so callers cannot pair an arbitrary
    /// endpoint with an unrelated hostname. A future IPC/FFI resolver must
    /// introduce an explicit provenance-carrying result type before exposing
    /// this boundary externally.
    fn from_addresses<I>(target: HostTarget, addresses: I) -> Result<Self, ResolveError>
    where
        I: IntoIterator<Item = SocketAddr>,
    {
        let mut approved = Vec::new();
        for address in addresses {
            if address.port() != target.port() {
                return Err(ResolveError::PortMismatch {
                    expected: target.port(),
                    actual: address.port(),
                });
            }
            if !is_allowed_ip(address.ip()) {
                return Err(ResolveError::UnsafeAddress {
                    address: address.ip(),
                });
            }
            if !approved.contains(&address) {
                approved.push(address);
            }
        }
        if approved.is_empty() {
            return Err(ResolveError::NoAddresses {
                hostname: target.hostname.clone(),
                port: target.port,
            });
        }
        Ok(Self {
            target,
            addresses: approved,
        })
    }

    /// The original hostname or authority input, retained for diagnostics.
    pub fn hostname(&self) -> &str {
        self.target.hostname()
    }

    /// The valid HTTP authority value. Bracketed IPv6 remains bracketed;
    /// DNS names and IPv4 literals are returned unchanged.
    pub fn http_authority(&self) -> &str {
        self.target.hostname()
    }

    /// The normalized server name for TLS SNI and certificate verification.
    /// IPv6 literals do not include URI authority brackets here; DNS names are
    /// returned unchanged.
    pub fn tls_server_name(&self) -> &str {
        self.target
            .hostname()
            .strip_prefix('[')
            .and_then(|value| value.strip_suffix(']'))
            .unwrap_or(self.target.hostname())
    }

    pub fn port(&self) -> u16 {
        self.target.port()
    }

    pub fn addresses(&self) -> &[SocketAddr] {
        &self.addresses
    }

    /// Connects only to the plan's approved addresses. No DNS lookup occurs
    /// here. Addresses are attempted in resolver order within one total timeout
    /// budget. The returned connection retains the original hostname metadata
    /// for the caller's HTTP/TLS layer.
    pub fn connect(&self, timeout: Duration) -> Result<PinnedConnection, ConnectError> {
        if timeout.is_zero() {
            return Err(ConnectError::InvalidTimeout);
        }
        let started = Instant::now();
        let mut failures = Vec::with_capacity(self.addresses.len());
        for &address in &self.addresses {
            let elapsed = Instant::now().saturating_duration_since(started);
            let remaining = timeout.saturating_sub(elapsed);
            if remaining.is_zero() {
                break;
            }
            match TcpStream::connect_timeout(&address, remaining) {
                Ok(stream) => {
                    return Ok(PinnedConnection {
                        stream,
                        hostname: self.target.hostname.clone(),
                        endpoint: address,
                    });
                }
                Err(error) => failures.push((address, error.kind())),
            }
        }
        Err(ConnectError::AllAttemptsFailed { failures })
    }
}

/// A TCP stream connected to a previously validated endpoint.
///
/// This type intentionally exposes the original hostname separately from the
/// socket peer. `ResearchFetcher` uses that hostname as TLS SNI and certificate
/// identity, never the IP address in `endpoint()`.
pub struct PinnedConnection {
    stream: TcpStream,
    hostname: String,
    endpoint: SocketAddr,
}

impl PinnedConnection {
    pub fn hostname(&self) -> &str {
        &self.hostname
    }

    pub fn endpoint(&self) -> SocketAddr {
        self.endpoint
    }

    pub fn peer_addr(&self) -> io::Result<SocketAddr> {
        self.stream.peer_addr()
    }

    pub fn into_tcp_stream(self) -> TcpStream {
        self.stream
    }

    pub fn tcp_stream(&self) -> &TcpStream {
        &self.stream
    }
}

/// Connection failures after resolution and policy validation.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ConnectError {
    InvalidTimeout,
    AllAttemptsFailed {
        failures: Vec<(SocketAddr, io::ErrorKind)>,
    },
}

impl fmt::Display for ConnectError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidTimeout => write!(f, "connection timeout must be greater than zero"),
            Self::AllAttemptsFailed { failures } => {
                write!(
                    f,
                    "all {} approved connection attempts failed",
                    failures.len()
                )
            }
        }
    }
}

impl std::error::Error for ConnectError {}

/// Returns false for private, local, special-use, and documentation ranges.
/// This intentionally fails closed for all unspecified, multicast, and
/// reserved addresses as a research fetcher must never reach local services.
pub fn is_allowed_ip(ip: IpAddr) -> bool {
    match ip {
        IpAddr::V4(ip) => is_allowed_ipv4(u32::from(ip)),
        IpAddr::V6(ip) => is_allowed_ipv6(ip.octets()),
    }
}

fn validate_hostname(hostname: &str) -> Result<(), ResolveError> {
    if hostname.trim().is_empty() {
        return Err(ResolveError::EmptyHostname);
    }
    if hostname.len() > 253
        || hostname.chars().any(|character| {
            character.is_control()
                || character.is_whitespace()
                || matches!(character, '/' | '?' | '#' | '%')
        })
    {
        return Err(ResolveError::InvalidHostname(hostname.to_owned()));
    }

    // IP literals are valid authority hosts. IPv6 must be bracketed at this
    // boundary so the value is valid as an HTTP authority; TLS gets the
    // bracket-free form through `tls_server_name()`.
    let is_bracketed = hostname.starts_with('[') && hostname.ends_with(']');
    let unbracketed = hostname
        .strip_prefix('[')
        .and_then(|value| value.strip_suffix(']'))
        .unwrap_or(hostname);
    if unbracketed.parse::<IpAddr>().is_ok() {
        if unbracketed.parse::<std::net::Ipv6Addr>().is_ok() && !is_bracketed {
            return Err(ResolveError::InvalidHostname(hostname.to_owned()));
        }
        if unbracketed.parse::<std::net::Ipv4Addr>().is_ok() && is_bracketed {
            return Err(ResolveError::InvalidHostname(hostname.to_owned()));
        }
        return Ok(());
    }
    if hostname.contains(['[', ']', ':']) {
        return Err(ResolveError::InvalidHostname(hostname.to_owned()));
    }

    for label in hostname.trim_end_matches('.').split('.') {
        if label.is_empty()
            || label.len() > 63
            || label.starts_with('-')
            || label.ends_with('-')
            || !label
                .chars()
                .all(|character| character.is_ascii_alphanumeric() || character == '-')
        {
            return Err(ResolveError::InvalidHostname(hostname.to_owned()));
        }
    }
    Ok(())
}

fn parse_ip_literal(hostname: &str) -> Option<IpAddr> {
    let unbracketed = hostname
        .strip_prefix('[')
        .and_then(|value| value.strip_suffix(']'))
        .unwrap_or(hostname);
    unbracketed.parse::<IpAddr>().ok()
}

fn is_allowed_ipv4(value: u32) -> bool {
    const BLOCKED: &[(u32, u32)] = &[
        (0x0000_0000, 0x00FF_FFFF), // 0/8
        (0x0A00_0000, 0x0AFF_FFFF), // 10/8
        (0x6440_0000, 0x647F_FFFF), // 100.64/10 CGNAT
        (0x7F00_0000, 0x7FFF_FFFF), // 127/8
        (0xA9FE_0000, 0xA9FE_FFFF), // 169.254/16
        (0xAC10_0000, 0xAC1F_FFFF), // 172.16/12
        (0xC000_0000, 0xC000_00FF), // 192.0.0/24
        (0xC000_0200, 0xC000_02FF), // 192.0.2/24 documentation
        (0xC058_6300, 0xC058_63FF), // 192.88.99/24 6to4 relay
        (0xC612_0000, 0xC613_FFFF), // 198.18/15 benchmark
        (0xC633_6400, 0xC633_64FF), // 198.51.100/24 documentation
        (0xC0A8_0000, 0xC0A8_FFFF), // 192.168/16
        (0xCB00_7100, 0xCB00_71FF), // 203.0.113/24 documentation
        (0xE000_0000, 0xEFFF_FFFF), // multicast
        (0xF000_0000, 0xFFFF_FFFF), // reserved
    ];
    !BLOCKED
        .iter()
        .any(|&(start, end)| (start..=end).contains(&value))
}

fn is_allowed_ipv6(octets: [u8; 16]) -> bool {
    let ip = std::net::Ipv6Addr::from(octets);
    if ip.is_unspecified() || ip.is_loopback() || ip.is_multicast() {
        return false;
    }
    let first = u16::from_be_bytes([octets[0], octets[1]]);
    // fc00::/7 unique-local and fe80::/10 link-local.
    if (first & 0xFE00) == 0xFC00 || (first & 0xFFC0) == 0xFE80 {
        return false;
    }
    // 2001:db8::/32 documentation.
    if octets[0..4] == [0x20, 0x01, 0x0D, 0xB8] {
        return false;
    }
    // IPv4-mapped values inherit the exact embedded IPv4 classification.
    // Check this before the deprecated ::/96 compatible space because the
    // mapped form has ff:ff in bytes 10–11 rather than twelve zero bytes.
    if octets[..10] == [0; 10] && octets[10..12] == [0xFF, 0xFF] {
        return is_allowed_ipv4(u32::from_be_bytes([
            octets[12], octets[13], octets[14], octets[15],
        ]));
    }
    // The deprecated ::/96 IPv4-compatible space must not become an escape
    // hatch for the IPv4 policy.
    if octets[..12] == [0; 12] {
        return false;
    }
    // 6to4 and Teredo are special tunneling spaces. Rejecting them avoids
    // hidden embedded-address semantics at a browser research boundary.
    if octets[0..2] == [0x20, 0x02] || octets[0..4] == [0x20, 0x01, 0x00, 0x00] {
        return false;
    }
    // Benchmarking (2001:2::/48), ORCHIDv1 (2001:10::/28), and ORCHIDv2
    // (2001:20::/28) are not public web destinations. Use masks matching the
    // allocated prefixes rather than broad guessed ranges.
    let first32 = u32::from_be_bytes([octets[0], octets[1], octets[2], octets[3]]);
    let first48 = u64::from_be_bytes([
        octets[0], octets[1], octets[2], octets[3], octets[4], octets[5], 0, 0,
    ]);
    if first48 == 0x2001_0002_0000_0000
        || (first32 & 0xFFFF_FFF0) == 0x2001_0010
        || (first32 & 0xFFFF_FFF0) == 0x2001_0020
    {
        return false;
    }
    true
}

/// A synchronous HTTPS/HTTP fetcher built on `ResolutionPlan`.
///
/// This layer intentionally owns no cookie jar, redirect-following client, or
/// ambient DNS resolver. Each redirect is parsed, policy-checked, resolved,
/// and connected again. HTTPS uses rustls with the original hostname as SNI
/// and certificate-verification name while TCP connects to the approved
/// `SocketAddr`.
pub struct ResearchFetcher {
    config: ResearchFetcherConfig,
    tls_config: Arc<ClientConfig>,
}

#[derive(Clone, Debug)]
pub struct ResearchFetcherConfig {
    pub max_redirects: usize,
    pub max_bytes: usize,
    pub timeout: Duration,
    pub user_agent: String,
}

impl Default for ResearchFetcherConfig {
    fn default() -> Self {
        Self {
            max_redirects: 5,
            max_bytes: 5 * 1024 * 1024,
            timeout: Duration::from_secs(15),
            user_agent: "HiveResearch/0.1".to_owned(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ResearchFetchError {
    InvalidUrl(String),
    InvalidTimeout,
    UnsupportedScheme(String),
    MissingHost,
    RedirectLimit,
    RedirectMissingLocation,
    ResponseTooLarge(usize),
    RedirectDowngrade,
    InformationalResponse(u16),
    InvalidRequestHeader,
    ConflictingContentLength,
    AmbiguousTransferEncoding,
    MalformedResponse(String),
    Io(io::ErrorKind),
    Tls(String),
    Resolve(ResolveError),
}

impl fmt::Display for ResearchFetchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidUrl(value) => write!(f, "invalid research URL: {value}"),
            Self::InvalidTimeout => write!(f, "research timeout must be greater than zero"),
            Self::UnsupportedScheme(value) => write!(f, "unsupported research scheme: {value}"),
            Self::MissingHost => write!(f, "research URL has no host"),
            Self::RedirectLimit => write!(f, "research redirect limit exceeded"),
            Self::RedirectMissingLocation => write!(f, "redirect has no Location header"),
            Self::ResponseTooLarge(bytes) => {
                write!(f, "research response is too large: {bytes} bytes")
            }
            Self::RedirectDowngrade => write!(f, "HTTPS research redirect to HTTP was blocked"),
            Self::InformationalResponse(status) => {
                write!(f, "unsupported informational HTTP response: {status}")
            }
            Self::InvalidRequestHeader => write!(
                f,
                "research request header contains invalid control characters"
            ),
            Self::ConflictingContentLength => write!(f, "conflicting Content-Length headers"),
            Self::AmbiguousTransferEncoding => {
                write!(f, "ambiguous or unsupported Transfer-Encoding")
            }
            Self::MalformedResponse(value) => write!(f, "malformed HTTP response: {value}"),
            Self::Io(kind) => write!(f, "research I/O failed: {kind:?}"),
            Self::Tls(value) => write!(f, "research TLS failed: {value}"),
            Self::Resolve(error) => write!(f, "research resolution failed: {error}"),
        }
    }
}

impl std::error::Error for ResearchFetchError {}

impl From<ResolveError> for ResearchFetchError {
    fn from(value: ResolveError) -> Self {
        Self::Resolve(value)
    }
}

pub struct ResearchFetchResult {
    pub final_url: Url,
    pub status: u16,
    pub content_type: Option<String>,
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
    pub redirect_count: usize,
}

impl ResearchFetcher {
    pub fn new(config: ResearchFetcherConfig) -> Result<Self, ResearchFetchError> {
        if config.timeout.is_zero() {
            return Err(ResearchFetchError::InvalidTimeout);
        }
        if contains_header_control(&config.user_agent) {
            return Err(ResearchFetchError::InvalidRequestHeader);
        }
        let mut roots = RootCertStore::empty();
        roots.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
        let tls_config = ClientConfig::builder()
            .with_root_certificates(roots)
            .with_no_client_auth();
        Ok(Self {
            config,
            tls_config: Arc::new(tls_config),
        })
    }

    pub fn with_defaults() -> Result<Self, ResearchFetchError> {
        Self::new(ResearchFetcherConfig::default())
    }

    /// Fetches one URL with manual, policy-controlled redirect handling.
    pub fn fetch(&self, initial: &str) -> Result<ResearchFetchResult, ResearchFetchError> {
        let mut url = Url::parse(initial)
            .map_err(|error| ResearchFetchError::InvalidUrl(error.to_string()))?;
        let mut redirect_count = 0;
        loop {
            let response = self.fetch_one(&url)?;
            if (300..400).contains(&response.status) {
                if redirect_count >= self.config.max_redirects {
                    return Err(ResearchFetchError::RedirectLimit);
                }
                let location = header_value(&response.headers, "location")
                    .ok_or(ResearchFetchError::RedirectMissingLocation)?;
                let next = url
                    .join(location.as_str())
                    .map_err(|error| ResearchFetchError::InvalidUrl(error.to_string()))?;
                validate_redirect(&url, &next)?;
                redirect_count += 1;
                url = next;
                continue;
            }
            return Ok(ResearchFetchResult {
                final_url: url,
                status: response.status,
                content_type: header_value(&response.headers, "content-type"),
                headers: response.headers,
                body: response.body,
                redirect_count,
            });
        }
    }

    fn fetch_one(&self, url: &Url) -> Result<RawResponse, ResearchFetchError> {
        validate_research_url(url)?;
        let host = url.host_str().ok_or(ResearchFetchError::MissingHost)?;
        let port = url
            .port_or_known_default()
            .ok_or(ResearchFetchError::MissingHost)?;
        let target_host = if host.parse::<std::net::Ipv6Addr>().is_ok() {
            format!("[{host}]")
        } else {
            host.to_owned()
        };
        let deadline = Instant::now()
            .checked_add(self.config.timeout)
            .ok_or(ResearchFetchError::Io(io::ErrorKind::InvalidInput))?;
        let plan = ResolutionPlan::resolve(target_host, port)?;
        let remaining = deadline
            .checked_duration_since(Instant::now())
            .ok_or(ResearchFetchError::Io(io::ErrorKind::TimedOut))?;
        let pinned = plan.connect(remaining).map_err(|error| {
            ResearchFetchError::Io(match error {
                ConnectError::InvalidTimeout => io::ErrorKind::InvalidInput,
                ConnectError::AllAttemptsFailed { failures } => failures
                    .last()
                    .map(|(_, kind)| *kind)
                    .unwrap_or(io::ErrorKind::Other),
            })
        })?;
        let mut stream = DeadlineTcpStream::new(pinned.into_tcp_stream(), deadline);

        let authority = authority_for(url)?;
        let request_target = request_target_for(url);
        if contains_header_control(&authority) || contains_header_control(&self.config.user_agent) {
            return Err(ResearchFetchError::InvalidRequestHeader);
        }
        let request = format!(
            "GET {request_target} HTTP/1.1\r\nHost: {authority}\r\nUser-Agent: {}\r\nAccept: text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.1\r\nAccept-Encoding: identity\r\nConnection: close\r\n\r\n",
            self.config.user_agent
        );

        let raw = if url.scheme() == "https" {
            let server_name = rustls::pki_types::ServerName::try_from(host.to_owned())
                .map_err(|error| ResearchFetchError::Tls(error.to_string()))?;
            let connection = ClientConnection::new(self.tls_config.clone(), server_name)
                .map_err(|error| ResearchFetchError::Tls(error.to_string()))?;
            let mut tls = StreamOwned::new(connection, stream);
            tls.write_all(request.as_bytes())
                .map_err(|error| ResearchFetchError::Io(error.kind()))?;
            tls.flush()
                .map_err(|error| ResearchFetchError::Io(error.kind()))?;
            read_http_response(&mut tls, self.config.max_bytes, deadline)?
        } else {
            stream
                .write_all(request.as_bytes())
                .map_err(|error| ResearchFetchError::Io(error.kind()))?;
            stream
                .flush()
                .map_err(|error| ResearchFetchError::Io(error.kind()))?;
            read_http_response(&mut stream, self.config.max_bytes, deadline)?
        };
        Ok(raw)
    }
}

fn contains_header_control(value: &str) -> bool {
    value
        .chars()
        .any(|character| character == '\r' || character == '\n' || character.is_control())
}

fn validate_redirect(current: &Url, next: &Url) -> Result<(), ResearchFetchError> {
    if current.scheme() == "https" && next.scheme() != "https" {
        return Err(ResearchFetchError::RedirectDowngrade);
    }
    validate_research_url(next)
}

fn validate_research_url(url: &Url) -> Result<(), ResearchFetchError> {
    match url.scheme() {
        "http" | "https" => {}
        scheme => return Err(ResearchFetchError::UnsupportedScheme(scheme.to_owned())),
    }
    if url.host_str().is_none() || url.username() != "" || url.password().is_some() {
        return Err(ResearchFetchError::MissingHost);
    }
    Ok(())
}

fn authority_for(url: &Url) -> Result<String, ResearchFetchError> {
    let host = url.host_str().ok_or(ResearchFetchError::MissingHost)?;
    let authority_host = if host.parse::<std::net::Ipv6Addr>().is_ok() {
        format!("[{host}]")
    } else {
        host.to_owned()
    };
    match url.port() {
        Some(port) => Ok(format!("{authority_host}:{port}")),
        None => Ok(authority_host),
    }
}

fn request_target_for(url: &Url) -> String {
    let mut target = url.path().to_owned();
    if target.is_empty() {
        target.push('/');
    }
    if let Some(query) = url.query() {
        target.push('?');
        target.push_str(query);
    }
    target
}

struct RawResponse {
    status: u16,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
}

struct DeadlineTcpStream {
    stream: TcpStream,
    deadline: Instant,
}

impl DeadlineTcpStream {
    fn new(stream: TcpStream, deadline: Instant) -> Self {
        Self { stream, deadline }
    }

    fn remaining(&self) -> io::Result<Duration> {
        self.deadline
            .checked_duration_since(Instant::now())
            .ok_or_else(|| io::Error::new(io::ErrorKind::TimedOut, "research deadline elapsed"))
    }
}

impl Read for DeadlineTcpStream {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let remaining = self.remaining()?;
        self.stream.set_read_timeout(Some(remaining))?;
        self.stream.read(buffer)
    }
}

impl Write for DeadlineTcpStream {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        let remaining = self.remaining()?;
        self.stream.set_write_timeout(Some(remaining))?;
        self.stream.write(buffer)
    }

    fn flush(&mut self) -> io::Result<()> {
        let remaining = self.remaining()?;
        self.stream.set_write_timeout(Some(remaining))?;
        self.stream.flush()
    }
}

trait DeadlineRead: Read {
    fn prepare_read(&mut self, remaining: Duration) -> io::Result<()>;
}

impl DeadlineRead for DeadlineTcpStream {
    fn prepare_read(&mut self, remaining: Duration) -> io::Result<()> {
        self.stream.set_read_timeout(Some(remaining))
    }
}

impl DeadlineRead for StreamOwned<ClientConnection, DeadlineTcpStream> {
    fn prepare_read(&mut self, remaining: Duration) -> io::Result<()> {
        self.get_mut().prepare_read(remaining)
    }
}

#[cfg(test)]
impl DeadlineRead for std::io::Cursor<Vec<u8>> {
    fn prepare_read(&mut self, _remaining: Duration) -> io::Result<()> {
        Ok(())
    }
}

fn read_at_deadline<R: DeadlineRead>(
    reader: &mut R,
    deadline: Instant,
    buffer: &mut [u8],
) -> Result<usize, ResearchFetchError> {
    let remaining = deadline
        .checked_duration_since(Instant::now())
        .ok_or(ResearchFetchError::Io(io::ErrorKind::TimedOut))?;
    reader
        .prepare_read(remaining)
        .map_err(|error| ResearchFetchError::Io(error.kind()))?;
    reader
        .read(buffer)
        .map_err(|error| ResearchFetchError::Io(error.kind()))
}

fn read_http_response<R: DeadlineRead>(
    reader: &mut R,
    max_bytes: usize,
    deadline: Instant,
) -> Result<RawResponse, ResearchFetchError> {
    let mut bytes = Vec::with_capacity(8192);
    let header_end = loop {
        let mut chunk = [0_u8; 4096];
        let count = read_at_deadline(reader, deadline, &mut chunk)?;
        if count == 0 {
            return Err(ResearchFetchError::MalformedResponse(
                "connection closed before headers".to_owned(),
            ));
        }
        bytes.extend_from_slice(&chunk[..count]);
        if bytes.len() > max_bytes.saturating_add(64 * 1024) {
            return Err(ResearchFetchError::ResponseTooLarge(bytes.len()));
        }
        if let Some(position) = bytes.windows(4).position(|window| window == b"\r\n\r\n") {
            break position + 4;
        }
    };

    let header_text = std::str::from_utf8(&bytes[..header_end])
        .map_err(|_| ResearchFetchError::MalformedResponse("headers are not UTF-8".to_owned()))?;
    let mut lines = header_text.split("\r\n");
    let status_line = lines
        .next()
        .ok_or_else(|| ResearchFetchError::MalformedResponse("missing status line".to_owned()))?;
    let mut status_parts = status_line.split_whitespace();
    let version = status_parts.next().unwrap_or_default();
    let status = status_parts
        .next()
        .ok_or_else(|| ResearchFetchError::MalformedResponse("missing status code".to_owned()))?
        .parse::<u16>()
        .map_err(|_| ResearchFetchError::MalformedResponse("invalid status code".to_owned()))?;
    if !version.starts_with("HTTP/") {
        return Err(ResearchFetchError::MalformedResponse(
            "invalid HTTP version".to_owned(),
        ));
    }
    if (100..200).contains(&status) {
        return Err(ResearchFetchError::InformationalResponse(status));
    }
    let mut headers = Vec::new();
    for line in lines {
        if line.is_empty() {
            continue;
        }
        let (name, value) = line.split_once(':').ok_or_else(|| {
            ResearchFetchError::MalformedResponse("header has no colon".to_owned())
        })?;
        headers.push((name.trim().to_ascii_lowercase(), value.trim().to_owned()));
    }
    let mut body = bytes[header_end..].to_vec();
    let content_lengths: Vec<&str> = headers
        .iter()
        .filter(|(name, _)| name.eq_ignore_ascii_case("content-length"))
        .map(|(_, value)| value.as_str())
        .collect();
    let transfer_encodings: Vec<&str> = headers
        .iter()
        .filter(|(name, _)| name.eq_ignore_ascii_case("transfer-encoding"))
        .map(|(_, value)| value.as_str())
        .collect();
    let expected_length = if content_lengths.is_empty() {
        None
    } else {
        let parsed: Result<Vec<usize>, _> = content_lengths
            .iter()
            .map(|value| value.trim().parse::<usize>())
            .collect();
        let parsed = parsed.map_err(|_| {
            ResearchFetchError::MalformedResponse("invalid Content-Length".to_owned())
        })?;
        if parsed.iter().any(|value| *value != parsed[0]) {
            return Err(ResearchFetchError::ConflictingContentLength);
        }
        Some(parsed[0])
    };
    if !transfer_encodings.is_empty() {
        if expected_length.is_some() {
            return Err(ResearchFetchError::AmbiguousTransferEncoding);
        }
        let coding = transfer_encodings.join(",");
        let codings: Vec<&str> = coding.split(',').map(str::trim).collect();
        if codings.len() != 1 || !codings[0].eq_ignore_ascii_case("chunked") {
            return Err(ResearchFetchError::AmbiguousTransferEncoding);
        }
    }
    if let Some(expected) = expected_length {
        if expected > max_bytes {
            return Err(ResearchFetchError::ResponseTooLarge(expected));
        }
        if body.len() > expected {
            return Err(ResearchFetchError::MalformedResponse(
                "body exceeds Content-Length".to_owned(),
            ));
        }
        while body.len() < expected {
            let remaining = expected - body.len();
            let mut chunk = vec![0_u8; remaining.min(8192)];
            let count = read_at_deadline(reader, deadline, &mut chunk)?;
            if count == 0 {
                return Err(ResearchFetchError::MalformedResponse(
                    "body shorter than Content-Length".to_owned(),
                ));
            }
            body.extend_from_slice(&chunk[..count]);
        }
        body.truncate(expected);
    } else if !transfer_encodings.is_empty() {
        body = decode_chunked(body, reader, max_bytes, deadline)?;
    } else {
        while body.len() <= max_bytes {
            let mut chunk = [0_u8; 8192];
            let count = read_at_deadline(reader, deadline, &mut chunk)?;
            if count == 0 {
                break;
            }
            body.extend_from_slice(&chunk[..count]);
            if body.len() > max_bytes {
                return Err(ResearchFetchError::ResponseTooLarge(body.len()));
            }
        }
        if body.len() > max_bytes {
            return Err(ResearchFetchError::ResponseTooLarge(body.len()));
        }
    }
    Ok(RawResponse {
        status,
        headers,
        body,
    })
}

fn consume_chunk_trailers<R: DeadlineRead>(
    buffered: &mut Vec<u8>,
    reader: &mut R,
    deadline: Instant,
) -> Result<(), ResearchFetchError> {
    const MAX_TRAILER_BYTES: usize = 64 * 1024;
    loop {
        if buffered.starts_with(b"\r\n") {
            buffered.drain(..2);
            return Ok(());
        }
        if let Some(position) = buffered.windows(4).position(|window| window == b"\r\n\r\n") {
            let trailer_text = std::str::from_utf8(&buffered[..position + 2]).map_err(|_| {
                ResearchFetchError::MalformedResponse("chunk trailers are not UTF-8".to_owned())
            })?;
            for line in trailer_text.split("\r\n").filter(|line| !line.is_empty()) {
                if line.split_once(':').is_none() {
                    return Err(ResearchFetchError::MalformedResponse(
                        "chunk trailer has no colon".to_owned(),
                    ));
                }
            }
            buffered.drain(..position + 4);
            return Ok(());
        }
        if buffered.len() > MAX_TRAILER_BYTES {
            return Err(ResearchFetchError::MalformedResponse(
                "chunk trailers are too large".to_owned(),
            ));
        }
        let mut chunk = [0_u8; 4096];
        let count = read_at_deadline(reader, deadline, &mut chunk)?;
        if count == 0 {
            return Err(ResearchFetchError::MalformedResponse(
                "truncated chunk trailers".to_owned(),
            ));
        }
        buffered.extend_from_slice(&chunk[..count]);
    }
}

fn decode_chunked<R: DeadlineRead>(
    mut buffered: Vec<u8>,
    reader: &mut R,
    max_bytes: usize,
    deadline: Instant,
) -> Result<Vec<u8>, ResearchFetchError> {
    let mut decoded = Vec::new();
    loop {
        let line_end = loop {
            if let Some(position) = buffered.windows(2).position(|window| window == b"\r\n") {
                break position;
            }
            let mut chunk = [0_u8; 4096];
            let count = read_at_deadline(reader, deadline, &mut chunk)?;
            if count == 0 {
                return Err(ResearchFetchError::MalformedResponse(
                    "truncated chunk size".to_owned(),
                ));
            }
            buffered.extend_from_slice(&chunk[..count]);
        };
        let size_text = std::str::from_utf8(&buffered[..line_end]).map_err(|_| {
            ResearchFetchError::MalformedResponse("chunk size is not UTF-8".to_owned())
        })?;
        let size_text = size_text.split(';').next().unwrap_or_default().trim();
        let size = usize::from_str_radix(size_text, 16)
            .map_err(|_| ResearchFetchError::MalformedResponse("invalid chunk size".to_owned()))?;
        buffered.drain(..line_end + 2);
        if size == 0 {
            consume_chunk_trailers(&mut buffered, reader, deadline)?;
            return Ok(decoded);
        }
        while buffered.len() < size + 2 {
            let mut chunk = [0_u8; 4096];
            let count = read_at_deadline(reader, deadline, &mut chunk)?;
            if count == 0 {
                return Err(ResearchFetchError::MalformedResponse(
                    "truncated chunk body".to_owned(),
                ));
            }
            buffered.extend_from_slice(&chunk[..count]);
        }
        decoded.extend_from_slice(&buffered[..size]);
        if decoded.len() > max_bytes {
            return Err(ResearchFetchError::ResponseTooLarge(decoded.len()));
        }
        if &buffered[size..size + 2] != b"\r\n" {
            return Err(ResearchFetchError::MalformedResponse(
                "chunk missing terminator".to_owned(),
            ));
        }
        buffered.drain(..size + 2);
    }
}

fn header_value(headers: &[(String, String)], name: &str) -> Option<String> {
    headers
        .iter()
        .find(|(key, _)| key.eq_ignore_ascii_case(name))
        .map(|(_, value)| value.clone())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::{Ipv4Addr, Ipv6Addr};

    fn v4(value: [u8; 4]) -> IpAddr {
        IpAddr::V4(Ipv4Addr::from(value))
    }

    fn v6(value: &str) -> IpAddr {
        IpAddr::V6(value.parse::<Ipv6Addr>().expect("valid IPv6 fixture"))
    }

    #[test]
    fn rejects_private_reserved_and_special_ipv4_ranges() {
        let blocked = [
            [0, 0, 0, 0],
            [10, 1, 2, 3],
            [100, 64, 0, 1],
            [127, 0, 0, 1],
            [169, 254, 169, 254],
            [172, 31, 255, 254],
            [192, 0, 0, 1],
            [192, 0, 2, 1],
            [192, 168, 1, 1],
            [198, 18, 0, 1],
            [198, 51, 100, 1],
            [203, 0, 113, 1],
            [224, 0, 0, 1],
            [255, 255, 255, 255],
        ];
        for address in blocked {
            assert!(!is_allowed_ip(v4(address)), "{address:?} must be blocked");
        }
    }

    #[test]
    fn allows_public_ipv4_fixtures() {
        for address in [[1, 1, 1, 1], [8, 8, 8, 8], [93, 184, 216, 34]] {
            assert!(is_allowed_ip(v4(address)), "{address:?} must be allowed");
        }
    }

    #[test]
    fn rejects_special_ipv6_and_mapped_private_ipv4() {
        for address in [
            "::",
            "::1",
            "fc00::1",
            "fd12:3456::1",
            "fe80::1",
            "2001:db8::1",
            "::ffff:127.0.0.1",
            "::ffff:192.168.1.1",
        ] {
            assert!(!is_allowed_ip(v6(address)), "{address} must be blocked");
        }
    }

    #[test]
    fn allows_public_ipv6_fixture() {
        assert!(is_allowed_ip(v6("2606:4700:4700::1111")));
    }

    #[test]
    fn plan_deduplicates_addresses_and_preserves_hostname() {
        let target = HostTarget::new("docs.example", 443).unwrap();
        let addresses = [
            SocketAddr::from(([93, 184, 216, 34], 443)),
            SocketAddr::from(([93, 184, 216, 34], 443)),
        ];
        let plan = ResolutionPlan::from_addresses(target, addresses).unwrap();
        assert_eq!(plan.hostname(), "docs.example");
        assert_eq!(plan.http_authority(), "docs.example");
        assert_eq!(plan.tls_server_name(), "docs.example");
        assert_eq!(plan.port(), 443);
        assert_eq!(plan.addresses().len(), 1);
    }

    #[test]
    fn plan_rejects_loopback_endpoint_before_connecting() {
        let target = HostTarget::new("local.example", 443).unwrap();
        let endpoint = SocketAddr::from(([127, 0, 0, 1], 443));
        assert_eq!(
            ResolutionPlan::from_addresses(target, [endpoint]),
            Err(ResolveError::UnsafeAddress {
                address: v4([127, 0, 0, 1]),
            })
        );
    }

    #[test]
    fn plan_fails_closed_if_any_answer_is_unsafe() {
        let target = HostTarget::new("mixed.example", 443).unwrap();
        let addresses = [
            SocketAddr::from(([93, 184, 216, 34], 443)),
            SocketAddr::from(([127, 0, 0, 1], 443)),
        ];
        assert_eq!(
            ResolutionPlan::from_addresses(target, addresses),
            Err(ResolveError::UnsafeAddress {
                address: v4([127, 0, 0, 1]),
            })
        );
    }

    #[test]
    fn plan_rejects_empty_or_invalid_hostnames() {
        assert_eq!(HostTarget::new("", 443), Err(ResolveError::EmptyHostname));
        assert!(matches!(
            HostTarget::new("bad host", 443),
            Err(ResolveError::InvalidHostname(_))
        ));
        assert!(matches!(
            HostTarget::new("2001:db8::1", 443),
            Err(ResolveError::InvalidHostname(_))
        ));
        assert!(matches!(
            HostTarget::new("[127.0.0.1]", 443),
            Err(ResolveError::InvalidHostname(_))
        ));
        assert!(matches!(
            HostTarget::new("[2606:4700:4700::1111%en0]", 443),
            Err(ResolveError::InvalidHostname(_))
        ));
        let target = HostTarget::new("empty.example", 443).unwrap();
        assert!(matches!(
            ResolutionPlan::from_addresses(target, std::iter::empty()),
            Err(ResolveError::NoAddresses { .. })
        ));
    }

    #[test]
    fn bracketed_ipv6_keeps_authority_but_normalizes_tls_name() {
        let target = HostTarget::new("[2606:4700:4700::1111]", 443).unwrap();
        let plan =
            ResolutionPlan::from_addresses(target, [SocketAddr::from(([93, 184, 216, 34], 443))])
                .unwrap();
        assert_eq!(plan.hostname(), "[2606:4700:4700::1111]");
        assert_eq!(plan.http_authority(), "[2606:4700:4700::1111]");
        assert_eq!(plan.tls_server_name(), "2606:4700:4700::1111");
    }

    #[test]
    fn plan_keeps_original_port_and_endpoint_port() {
        let target = HostTarget::new("docs.example.", 8443).unwrap();
        let endpoint = SocketAddr::from(([93, 184, 216, 34], 8443));
        let plan = ResolutionPlan::from_addresses(target, [endpoint]).unwrap();
        assert_eq!(plan.port(), 8443);
        assert_eq!(plan.addresses(), &[endpoint]);
    }

    #[test]
    fn plan_rejects_an_endpoint_with_a_different_port() {
        let target = HostTarget::new("docs.example", 443).unwrap();
        let endpoint = SocketAddr::from(([93, 184, 216, 34], 8443));
        assert!(matches!(
            ResolutionPlan::from_addresses(target, [endpoint]),
            Err(ResolveError::PortMismatch {
                expected: 443,
                actual: 8443
            })
        ));
    }

    #[test]
    fn rejects_ipv4_compatible_private_escape_and_special_ipv6_spaces() {
        for address in [
            "::192.168.1.1",
            "2002:c0a8:0101::1",
            "2001:0000:4136:e378::1",
            "2001:2::1",
            "2001:10::1",
            "2001:20::1",
        ] {
            assert!(!is_allowed_ip(v6(address)), "{address} must be blocked");
        }
    }

    #[test]
    fn connect_rejects_zero_timeout_before_attempting_a_socket() {
        let target = HostTarget::new("docs.example", 443).unwrap();
        let endpoint = SocketAddr::from(([93, 184, 216, 34], 443));
        let plan = ResolutionPlan::from_addresses(target, [endpoint]).unwrap();
        assert!(matches!(
            plan.connect(Duration::ZERO),
            Err(ConnectError::InvalidTimeout)
        ));
    }

    #[test]
    fn parses_content_length_response_with_real_crlf_framing() {
        use std::io::Cursor;

        let mut reader = Cursor::new(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhello"
                .to_vec(),
        );
        let response =
            read_http_response(&mut reader, 32, Instant::now() + Duration::from_secs(1)).unwrap();
        assert_eq!(response.status, 200);
        assert_eq!(response.body, b"hello");
        assert_eq!(
            header_value(&response.headers, "content-type").as_deref(),
            Some("text/plain")
        );
    }

    #[test]
    fn parses_chunked_response_and_validates_trailers() {
        use std::io::Cursor;

        let mut reader = Cursor::new(
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nX-Trace: ok\r\n\r\n".to_vec(),
        );
        let response =
            read_http_response(&mut reader, 32, Instant::now() + Duration::from_secs(1)).unwrap();
        assert_eq!(response.body, b"hello");
    }

    #[test]
    fn rejects_ambiguous_framing_and_malformed_chunk_trailers() {
        use std::io::Cursor;

        let mut conflicting = Cursor::new(
            b"HTTP/1.1 200 OK\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\na".to_vec(),
        );
        assert!(matches!(
            read_http_response(
                &mut conflicting,
                32,
                Instant::now() + Duration::from_secs(1)
            ),
            Err(ResearchFetchError::ConflictingContentLength)
        ));

        let mut both = Cursor::new(
            b"HTTP/1.1 200 OK\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n".to_vec(),
        );
        assert!(matches!(
            read_http_response(&mut both, 32, Instant::now() + Duration::from_secs(1)),
            Err(ResearchFetchError::AmbiguousTransferEncoding)
        ));

        let mut bad_trailer = Cursor::new(
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n0\r\nnot-a-header\r\n\r\n"
                .to_vec(),
        );
        assert!(matches!(
            read_http_response(&mut bad_trailer, 32, Instant::now() + Duration::from_secs(1)),
            Err(ResearchFetchError::MalformedResponse(message)) if message.contains("trailer")
        ));
    }

    #[test]
    fn rejects_eof_body_that_exceeds_the_limit_and_informational_status() {
        use std::io::Cursor;

        let mut oversized = Cursor::new(b"HTTP/1.1 200 OK\r\n\r\nhello!".to_vec());
        assert!(matches!(
            read_http_response(&mut oversized, 5, Instant::now() + Duration::from_secs(1)),
            Err(ResearchFetchError::ResponseTooLarge(6))
        ));

        let mut informational = Cursor::new(b"HTTP/1.1 103 Early Hints\r\n\r\n".to_vec());
        assert!(matches!(
            read_http_response(
                &mut informational,
                32,
                Instant::now() + Duration::from_secs(1)
            ),
            Err(ResearchFetchError::InformationalResponse(103))
        ));
    }

    #[test]
    fn rejects_content_length_overflow_and_zero_timeout() {
        use std::io::Cursor;

        let mut overflow =
            Cursor::new(b"HTTP/1.1 200 OK\r\nContent-Length: 3\r\n\r\nhello".to_vec());
        assert!(matches!(
            read_http_response(&mut overflow, 32, Instant::now() + Duration::from_secs(1)),
            Err(ResearchFetchError::MalformedResponse(message))
                if message.contains("Content-Length")
        ));
        assert!(matches!(
            ResearchFetcher::new(ResearchFetcherConfig {
                timeout: Duration::ZERO,
                ..ResearchFetcherConfig::default()
            }),
            Err(ResearchFetchError::InvalidTimeout)
        ));
    }

    #[test]
    fn enforces_request_and_redirect_policy() {
        let invalid_header = ResearchFetcher::new(ResearchFetcherConfig {
            user_agent: "Hive\r\nInjected: true".to_owned(),
            ..ResearchFetcherConfig::default()
        });
        assert!(matches!(
            invalid_header,
            Err(ResearchFetchError::InvalidRequestHeader)
        ));
        let https = Url::parse("https://example.com/start").unwrap();
        let http = Url::parse("http://example.com/next").unwrap();
        assert_eq!(
            validate_redirect(&https, &http),
            Err(ResearchFetchError::RedirectDowngrade)
        );
        assert_eq!(
            validate_research_url(&Url::parse("file:///tmp/secret").unwrap()),
            Err(ResearchFetchError::UnsupportedScheme("file".to_owned()))
        );
        assert_eq!(
            validate_research_url(&Url::parse("https://user:pass@example.com").unwrap()),
            Err(ResearchFetchError::MissingHost)
        );
    }

    #[test]
    fn connect_uses_the_supplied_endpoint_and_preserves_hostname() {
        use std::net::TcpListener;
        use std::thread;

        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).unwrap();
        let endpoint = listener.local_addr().unwrap();
        let accept = thread::spawn(move || {
            let (stream, _) = listener.accept().unwrap();
            stream.local_addr().unwrap()
        });

        // This test deliberately constructs the private plan directly so it
        // can exercise the connection primitive against a local listener
        // without weakening production address policy. The raw-address seam
        // is private to this crate, so external callers cannot bypass the
        // resolver provenance boundary.
        let plan = ResolutionPlan {
            target: HostTarget::new("docs.example", endpoint.port()).unwrap(),
            addresses: vec![endpoint],
        };
        let connection = plan.connect(Duration::from_secs(2)).unwrap();
        assert_eq!(connection.hostname(), "docs.example");
        assert_eq!(connection.endpoint(), endpoint);
        assert_eq!(connection.peer_addr().unwrap(), accept.join().unwrap());
    }
}
