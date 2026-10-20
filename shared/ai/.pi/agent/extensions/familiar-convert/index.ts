// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. It needs `markitdown` and `docling` on PATH (uv tools;
// install lines in 06_SYSTEM/dev/orchestration/2026-10-20-pdf-convert.md).
export { default } from "/home/rg/06_SYSTEM/engine/harness/pi-convert/index.ts";
