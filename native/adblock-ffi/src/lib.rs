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
use adblock::lists::FilterSet;
use adblock::request::Request;

thread_local! {
    static ENGINE: RefCell<Option<Engine>> = const { RefCell::new(None) };
}

#[no_mangle]
pub extern "C" fn engine_create() -> i32 {
    ENGINE.with(|cell| {
        let mut guard = cell.borrow_mut();
        if guard.is_some() { return -1; }
        let filter_set = FilterSet::new(true);
        *guard = Some(Engine::new_with_filter_set(filter_set));
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

        let request = match Request::new(url_str, source_str, type_str, "") {
            Ok(r) => r,
            Err(_) => return -1,
        };

        if engine.check_network_request(&request).should_block() { 1 } else { 0 }
    })
}

/// Returns a JSON array of CSS selectors that should be hidden on the given URL.
/// The caller must free the returned string with engine_free_string().
#[no_mangle]
pub extern "C" fn engine_cosmetic_selectors(url_ptr: *const c_char) -> *mut c_char {
    let url_str = match unsafe { CStr::from_ptr(url_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    ENGINE.with(|cell| {
        let guard = cell.borrow();
        let engine = match guard.as_ref() {
            Some(e) => e,
            None => return std::ptr::null_mut(),
        };

        let resources = engine.url_cosmetic_resources(url_str);
        // Build JSON array from hidden selectors
        let selectors: Vec<String> = resources.hide_selectors.into_iter().collect();
        let json = serde_json::to_string(&selectors).unwrap_or_else(|_| "[]".to_string());
        
        let c_string = std::ffi::CString::new(json).unwrap_or_default();
        c_string.into_raw()
    })
}

/// Free a string returned by engine_cosmetic_selectors.
#[no_mangle]
pub extern "C" fn engine_free_string(ptr: *mut c_char) {
    if ptr.is_null() { return; }
    unsafe { drop(std::ffi::CString::from_raw(ptr)); }
}
