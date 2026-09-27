//! C ABI for the Basecamp module (header: `include/wallet_engine.h`).
//!
//! JSON in, JSON out. Panics are caught at the boundary and returned as
//! errors, because unwinding into C++ is undefined behaviour.
#![allow(
    unsafe_code,
    reason = "C ABI boundary; every unsafe block is commented"
)]

use std::ffi::{CStr, CString, c_char};
use std::panic::{AssertUnwindSafe, catch_unwind};

use serde_json::{Value, json};

use crate::api;

fn to_c(v: &Value) -> *mut c_char {
    // serde_json never emits interior NULs; fall back to a fixed error if it ever did.
    CString::new(v.to_string())
        .unwrap_or_else(|_| {
            c"{\"ok\":false,\"error\":{\"code\":-32603,\"message\":\"nul in output\"}}".to_owned()
        })
        .into_raw()
}

fn guarded(f: impl FnOnce() -> Value) -> *mut c_char {
    let out = catch_unwind(AssertUnwindSafe(f)).unwrap_or_else(
        |_| json!({ "ok": false, "error": { "code": -32603, "message": "engine panicked" } }),
    );
    to_c(&out)
}

#[unsafe(no_mangle)]
pub extern "C" fn lk_engine_info() -> *mut c_char {
    guarded(|| api::ok(api::info()))
}

/// # Safety
/// `request_json` must be a valid NUL-terminated UTF-8 string, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_call(request_json: *const c_char) -> *mut c_char {
    guarded(|| {
        if request_json.is_null() {
            return api::err(-32600, "null request");
        }
        // SAFETY: non-null and NUL-terminated per the contract above; the
        // caller keeps it alive for the duration of this call.
        let raw = unsafe { CStr::from_ptr(request_json) };
        match raw.to_str() {
            Ok(s) => api::dispatch(s),
            Err(_) => api::err(-32600, "request is not UTF-8"),
        }
    })
}

/// Start the service: `{"dataDir": "<module data directory>"}`. Idempotent.
///
/// # Safety
/// `config_json` must be a valid NUL-terminated UTF-8 string, or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_init(config_json: *const c_char) -> *mut c_char {
    guarded(|| {
        if config_json.is_null() {
            return api::err(-32600, "null config");
        }
        // SAFETY: non-null and NUL-terminated per the contract above.
        match unsafe { CStr::from_ptr(config_json) }.to_str() {
            Ok(s) => crate::service::init(s),
            Err(_) => api::err(-32600, "config is not UTF-8"),
        }
    })
}

/// Queued events (JSON array, oldest first) since the last call.
#[unsafe(no_mangle)]
pub extern "C" fn lk_engine_events() -> *mut c_char {
    guarded(crate::service::drain_events)
}

/// # Safety
/// `s` must be a pointer returned by this library, freed at most once.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn lk_engine_free(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: `s` came from CString::into_raw in `to_c` and is freed once.
        drop(unsafe { CString::from_raw(s) });
    }
}
