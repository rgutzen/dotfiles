// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Speech for a session's replies, off by default: /voice,
// ctrl+alt+v (dev/voice-out C4).
export { default } from "/home/rg/06_SYSTEM/engine/voice/pi-voice/index.ts";
