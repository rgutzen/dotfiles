// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. On by default; inert inside a pi-agent child (PI_OFFLINE=1).
export { default } from "/home/rg/06_SYSTEM/engine/orchestration/trigger/pi-trigger/index.ts";
