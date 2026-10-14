// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Off unless PI_BINDINGS=1 (see the source's header).
export { default } from "/home/rg/06_SYSTEM/engine/orchestration/pi-bindings/index.ts";
