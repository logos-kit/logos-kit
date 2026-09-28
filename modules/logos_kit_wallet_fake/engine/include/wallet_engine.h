/* Logos Kit wallet engine: C ABI (crates/wallet-engine/src/ffi.rs).
 *
 * Every call takes and returns UTF-8 JSON. Returned strings are owned by the
 * engine and must be released with lk_engine_free. Calls never panic across
 * the boundary; failures come back as {"ok":false,"error":{code,message}}.
 */
#ifndef LOGOS_KIT_WALLET_ENGINE_H
#define LOGOS_KIT_WALLET_ENGINE_H

#ifdef __cplusplus
extern "C" {
#endif

/* {"ok":true,"result":{"engine":"<semver>","lezRev":"<40-hex>"}} */
char *lk_engine_info(void);

/* Start the long-lived service once: {"dataDir":"<path>"}. Idempotent. */
char *lk_engine_init(const char *config_json);

/* request: {"method":"<name>","params":{...},"caller":<host-attested caller>}
 *   -> {"ok":bool,"result"|"error"}
 * `caller` must come from the host (current_caller()), never from the app. */
char *lk_engine_call(const char *request_json);

/* Queued events since the last call: [{"event":"<name>",...}] (no private data). */
char *lk_engine_events(void);

void lk_engine_free(char *s);

#ifdef __cplusplus
}
#endif

#endif
