// Loader shim, stowed by the `ai` package so a fresh machine gets it.
//
// Pi auto-discovers extensions from ~/.pi/agent/extensions/*/index.ts. The
// implementation is version-controlled in 06_SYSTEM — edit the source there,
// never this file. It re-registers the builtin `read` as sequential, so a read
// waits for the bash that writes its file (06_SYSTEM dev/call-batching).
//
// The path is built from the home directory at load time: this repository is
// public, and its leak gate refuses a new literal home path.
import os from "node:os";
import path from "node:path";

export default async function (pi: unknown): Promise<void> {
  const target = path.join(os.homedir(), "06_SYSTEM/engine/harness/pi-sequential-read/index.ts");
  const { default: factory } = await import(target);
  await factory(pi);
}
