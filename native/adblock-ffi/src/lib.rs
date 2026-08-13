//! C FFI wrapper around Brave's adblock-rust engine for Hive Browser.
//!
//! Exposes a minimal C ABI surface for Swift integration:
//! - engine_create / engine_destroy
//! - engine_add_filters
//! - engine_check_url
//! - engine_cosmetic_selectors / engine_free_string
//!
//! The engine is stored in a global `Mutex` so a single instance is visible
//! from every thread that consults it. `adblock::Engine` is `Send + Sync` in
//! v0.13 (asserted upstream), so the main actor (which creates the engine and
//! seeds its filters) and CEF's browser-process IO thread (which performs
//! per-request checks) can share it safely.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Mutex;

use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;
use adblock::Engine;

static ENGINE: Mutex<Option<Engine>> = Mutex::new(None);

/// Creates an empty engine (filters are loaded via `engine_add_filters`).
/// Returns 0 on success, or -1 if an engine already exists or the lock is
/// poisoned.
#[no_mangle]
pub extern "C" fn engine_create() -> i32 {
    let mut guard = match ENGINE.lock() {
        Ok(g) => g,
        Err(_) => return -1,
    };
    if guard.is_some() {
        return -1;
    }
    *guard = Some(Engine::new_with_filter_set(FilterSet::new(false)));
    0
}

#[no_mangle]
pub extern "C" fn engine_destroy() {
    if let Ok(mut guard) = ENGINE.lock() {
        *guard = None;
    }
}

/// Loads an EasyList-format filter list and rebuilds the engine with it.
/// Filters that fail to parse are ignored by adblock-rust. Returns the number
/// of non-empty filter lines parsed, or -1 on error (null pointer, invalid
/// UTF-8, or a poisoned lock).
#[no_mangle]
pub extern "C" fn engine_add_filters(filters_ptr: *const c_char) -> i32 {
    if filters_ptr.is_null() {
        return -1;
    }
    let filters_str = match unsafe { CStr::from_ptr(filters_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let count = filters_str.lines().filter(|l| !l.is_empty()).count();
    if count == 0 {
        return 0;
    }

    let mut filter_set = FilterSet::new(false);
    filter_set.add_filter_list(filters_str.to_string(), ParseOptions::default());
    let engine = Engine::new_with_filter_set(filter_set);

    let mut guard = match ENGINE.lock() {
        Ok(g) => g,
        Err(_) => return -1,
    };
    *guard = Some(engine);
    count as i32
}

#[no_mangle]
pub extern "C" fn engine_check_url(
    url_ptr: *const c_char,
    source_hostname_ptr: *const c_char,
    request_type_ptr: *const c_char,
) -> i32 {
    if url_ptr.is_null() {
        return -1;
    }
    let url_str = match unsafe { CStr::from_ptr(url_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let source_str = match unsafe { CStr::from_ptr(source_hostname_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let request_type_str = if request_type_ptr.is_null() {
        "other"
    } else {
        match unsafe { CStr::from_ptr(request_type_ptr) }.to_str() {
            Ok(s) => s,
            Err(_) => return -1,
        }
    };

    let type_str = match request_type_str {
        "script" => "script",
        "image" => "image",
        "stylesheet" => "stylesheet",
        "xmlhttprequest" | "xhr" => "xmlhttprequest",
        "subdocument" | "iframe" => "subdocument",
        "media" => "media",
        "font" => "font",
        "websocket" => "websocket",
        _ => "other",
    };

    let request = match Request::new(url_str, source_str, type_str, "") {
        Ok(r) => r,
        Err(_) => return -1,
    };

    let guard = match ENGINE.lock() {
        Ok(g) => g,
        Err(_) => return -1,
    };
    let engine = match guard.as_ref() {
        Some(e) => e,
        None => return -1,
    };

    if engine.check_network_request(&request).should_block() {
        1
    } else {
        0
    }
}

/// Returns a JSON array of CSS selectors that should be hidden on the given URL.
/// The caller must free the returned string with engine_free_string().
#[no_mangle]
pub extern "C" fn engine_cosmetic_selectors(url_ptr: *const c_char) -> *mut c_char {
    if url_ptr.is_null() {
        return std::ptr::null_mut();
    }
    let url_str = match unsafe { CStr::from_ptr(url_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let guard = match ENGINE.lock() {
        Ok(g) => g,
        Err(_) => return std::ptr::null_mut(),
    };
    let engine = match guard.as_ref() {
        Some(e) => e,
        None => return std::ptr::null_mut(),
    };

    let resources = engine.url_cosmetic_resources(url_str);
    let selectors: Vec<String> = resources.hide_selectors.into_iter().collect();
    let json = serde_json::to_string(&selectors).unwrap_or_else(|_| "[]".to_string());

    let c_string = CString::new(json).unwrap_or_default();
    c_string.into_raw()
}

/// Free a string returned by engine_cosmetic_selectors.
#[no_mangle]
pub extern "C" fn engine_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe { drop(CString::from_raw(ptr)); }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    fn c(s: &str) -> CString {
        CString::new(s).unwrap()
    }

    // A single test exercises the full lifecycle against the shared global
    // engine so no two tests race on `ENGINE`.
    #[test]
    fn end_to_end_blocking_and_cosmetic() {
        engine_destroy();

        assert_eq!(engine_create(), 0);
        assert_eq!(engine_create(), -1, "second create must fail");

        // Empty engine: nothing is blocked yet.
        let blocked_url = c("https://doubleclick.net/ads/pixel.gif");
        let src = c("");
        let script = c("script");
        assert_eq!(
            engine_check_url(blocked_url.as_ptr(), src.as_ptr(), script.as_ptr()),
            0
        );

        // Load a real filter list (network rule + cosmetic rule).
        let filters = c("||doubleclick.net^\nexample.com##.ad-banner\n");
        let added = engine_add_filters(filters.as_ptr());
        assert!(added >= 2, "expected at least 2 filters, got {added}");

        // Blocked host now blocks; a subdomain of it blocks too.
        assert_eq!(
            engine_check_url(blocked_url.as_ptr(), src.as_ptr(), script.as_ptr()),
            1
        );
        let subdomain = c("https://ad.doubleclick.net/pagead/x");
        assert_eq!(
            engine_check_url(subdomain.as_ptr(), src.as_ptr(), script.as_ptr()),
            1
        );

        // Unrelated host is allowed.
        let allowed = c("https://example.com/page.html");
        assert_eq!(
            engine_check_url(allowed.as_ptr(), src.as_ptr(), script.as_ptr()),
            0
        );

        // Cosmetic selectors are returned for the page that owns the rule.
        let page = c("https://example.com/");
        let sel_ptr = engine_cosmetic_selectors(page.as_ptr());
        assert!(!sel_ptr.is_null(), "cosmetic selectors must not be null");
        let json = unsafe { CStr::from_ptr(sel_ptr) }.to_str().unwrap().to_string();
        engine_free_string(sel_ptr);
        let parsed: Vec<String> = serde_json::from_str(&json).unwrap();
        assert!(
            parsed.iter().any(|s| s.contains("ad-banner")),
            "expected `.ad-banner` selector, got {json}"
        );

        engine_destroy();
        // After destroy, checks report "not ready" (-1) rather than a verdict.
        assert_eq!(
            engine_check_url(blocked_url.as_ptr(), src.as_ptr(), script.as_ptr()),
            -1
        );
    }
}
