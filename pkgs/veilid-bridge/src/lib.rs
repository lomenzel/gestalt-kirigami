use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Arc, OnceLock};
use tokio::runtime::Runtime;
use veilid_core::{VeilidAPI, VeilidUpdate};

static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static API: OnceLock<VeilidAPI> = OnceLock::new();

type EventCallback = extern "C" fn(*const c_char);

#[no_mangle]
pub extern "C" fn gestalt_veilid_init(
    config_json: *const c_char,
    callback: EventCallback,
) -> bool {
    let rt = RUNTIME.get_or_init(|| Runtime::new().unwrap());

    let config_str = unsafe {
        if config_json.is_null() {
            "{}"
        } else {
            CStr::from_ptr(config_json).to_str().unwrap_or("{}")
        }
    };

    // Callback pointer wrapper so it can safely be sent across Tokio worker threads
    #[derive(Clone, Copy)]
    struct CallbackWrapper(EventCallback);
    unsafe impl Send for CallbackWrapper {}
    unsafe impl Sync for CallbackWrapper {}
    let cb_wrapper = CallbackWrapper(callback);

    // 1. Wrap the closure in Arc<dyn Fn(VeilidUpdate) + Send + Sync>
    let update_cb: Arc<dyn Fn(VeilidUpdate) + Send + Sync> = Arc::new(move |update: VeilidUpdate| {
        if let Ok(json) = serde_json::to_string(&update) {
            if let Ok(c_str) = CString::new(json) {
                (cb_wrapper.0)(c_str.as_ptr());
            }
        }
    });

    rt.block_on(async move {
        // 2. Call api_startup_json instead of api_startup since config is a JSON string
        match veilid_core::api_startup_json(update_cb, config_str.to_string()).await {
            Ok(api) => {
                let _ = API.set(api);
                true
            }
            Err(e) => {
                eprintln!("[Veilid Native Bridge] Startup failed: {:?}", e);
                false
            }
        }
    })
}

#[no_mangle]
pub extern "C" fn gestalt_veilid_run_effect(
    effect_json: *const c_char,
    response_cb: extern "C" fn(u64, *const c_char),
    request_id: u64,
) {
    let Some(rt) = RUNTIME.get() else { return; };
    let Some(api) = API.get() else { return; };

    let effect_str = unsafe {
        if effect_json.is_null() {
            return;
        }
        match CStr::from_ptr(effect_json).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return,
        }
    };

    let api = api.clone();

    #[derive(Clone, Copy)]
    struct RespWrapper(extern "C" fn(u64, *const c_char));
    unsafe impl Send for RespWrapper {}
    unsafe impl Sync for RespWrapper {}
    let resp = RespWrapper(response_cb);

    rt.spawn(async move {
        let result = handle_effect(&api, &effect_str).await;
        if let Ok(c_res) = CString::new(result) {
            (resp.0)(request_id, c_res.as_ptr());
        }
    });
}

async fn handle_effect(_api: &VeilidAPI, _json: &str) -> String {
    serde_json::json!({ "status": "ok" }).to_string()
}