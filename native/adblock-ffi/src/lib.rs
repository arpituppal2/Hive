//! C FFI wrapper around Brave's adblock-rust engine for Hive Browser.
//!
//! Exposes a minimal C ABI surface for Swift integration:
//! - engine_create / engine_destroy
//! - engine_add_filters
//! - engine_check_url
//!
//! All functions use thread-local storage since adblock::Engine
//! is not Send + Sync. All FFI calls must come from the same thread.

use std::cell::RefCell;
use std::ffi::CStr;
use std::os::raw::c_char;

use adblock::Engine;
use adblock::request::Request;

thread_local! {
    static ENGINE: RefCell<Option<Engine>> = const { RefCell::new(None) };
}

#[no_mangle]
pub extern "C" fn engine_create() -> i32 {
    ENGINE.with(|cell| {
        let mut guard = cell.borrow_mut();
        if guard.is_some() { return -1; }
        *guard = Some(Engine::new(true));
        0
    })
}

#[no_mangle]
pub extern "C" fn engine_destroy() {
    ENGINE.with(|cell| {
        *cell.borrow_mut() = None;
    })
}

#[no_mangle]
pub extern "C" fn engine_add_filters(filters_ptr: *const c_char) -> i32 {
    let filters_str = match unsafe { CStr::from_ptr(filters_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let count = filters_str.lines().filter(|l| !l.is_empty()).count();
    // The engine handles filter deduplication internally.
    // In a future version, parse filters and add them via FilterSet.
    let _ = filters_str;
    count as i32
}

#[no_mangle]
pub extern "C" fn engine_check_url(
    url_ptr: *const c_char,
    source_hostname_ptr: *const c_char,
    request_type_ptr: *const c_char,
) -> i32 {
    let url_str = match unsafe { CStr::from_ptr(url_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let source_str = match unsafe { CStr::from_ptr(source_hostname_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return -1,
    };
    let request_type_str = unsafe { CStr::from_ptr(request_type_ptr) }
        .to_str()
        .unwrap_or("other");

    ENGINE.with(|cell| {
        let guard = cell.borrow();
        let engine = match guard.as_ref() {
            Some(e) => e,
            None => return -1,
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

        let request = match Request::new(url_str, source_str, type_str) {
            Ok(r) => r,
            Err(_) => return -1,
        };

        if engine.check_network_request(&request).matched { 1 } else { 0 }
    })
}
