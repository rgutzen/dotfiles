// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. It registers the `familiar-delegations` chain link, which
// grants nothing until it is named in `authorizerChain` (item 8d).
export { default } from "/home/rg/06_SYSTEM/engine/orchestration/pi-asks/index.ts";
