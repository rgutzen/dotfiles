// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. The `ask_user` tool: a terminal dialog in an interactive
// session, a relay ask under RPC (dev/remote R2b).
export { default } from "/home/rg/06_SYSTEM/engine/relay/pi-ask-user/index.ts";
