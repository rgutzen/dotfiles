// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Away from the keyboard, dialogs and turn ends go to the
// phone through the relay; it registers the `familiar-remote` chain link
// (dev/remote R3a-R3d). With no relay running, asks stay at the terminal.
export { default } from "/home/rg/06_SYSTEM/engine/relay/pi-remote/index.ts";
