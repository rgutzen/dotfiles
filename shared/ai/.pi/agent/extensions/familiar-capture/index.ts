// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. Sibling: familiar-guard (boundaries), rtk.ts (command
// rewrites).
import { homedir } from "node:os";
const mod = await import(`${homedir()}/06_SYSTEM/engine/context/pi-capture/index.ts`);
export default mod.default;
