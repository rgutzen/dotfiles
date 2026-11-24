// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. The two one-liners on every ask, item 8g.
import { homedir } from "node:os";
const mod = await import(`${homedir()}/06_SYSTEM/engine/boundaries/pi-explain/index.ts`);
export default mod.default;
