// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Off unless PI_DEEPEN=1 (see the source's header).
//
// ORDER MATTERS ON A FRESH MACHINE: the target below exists only once
// 06_SYSTEM's `feat/deepen` is merged, so stow this AFTER that merge — a shim
// pointing at an absent file is a load error on every `pi` start.
export { default } from "/home/rg/06_SYSTEM/engine/orchestration/pi-deepen/index.ts";
