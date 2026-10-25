// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Sibling: familiar-guard (boundaries), familiar-capture
// (session capture), rtk.ts (command rewrites).
export { default } from "/home/rg/06_SYSTEM/engine/context/pi-loadout/index.ts";
