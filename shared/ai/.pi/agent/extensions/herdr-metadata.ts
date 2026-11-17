// herdr-metadata — reports the session's model and topic to herdr's sidebar.
//
// Thin shim: herdr owns rendering. The sidebar shows the tokens through the
// `$model` and `$summary` entries of [ui.sidebar.agents] in config.toml.base.
//   model=<id>      on session start and on every model change
//   summary=<name>  whenever the session name changes (auto-topic writes it)
//   sandbox=<glyph> on session start: whether this pi runs under the familiar
//                   launcher (06_SYSTEM dev/privacy). One Nerd Font glyph, so the
//                   sidebar shows a coloured icon instead of more text:
//                     \uf023 lock    mounts AND the network cut (FAMILIAR_EGRESS=1)
//                     \uf132 shield  mounts only, network open (main's launcher, or the
//                                    FAMILIAR_NO_EGRESS hatch)
//                     \uf09c unlock  not sandboxed
//                   The colours are config.toml.base's rules on `$sandbox`.
//
// Silent no-op outside herdr: HERDR_ENV or HERDR_PANE_ID unset.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

const REPORT_TIMEOUT_MS = 2_000

// The launcher's marks are set at exec and never change in a session.
function sandboxGlyph(env = process.env): string {
  if (env.FAMILIAR_SANDBOX !== "1") return "\uf09c"
  return env.FAMILIAR_EGRESS === "1" ? "\uf023" : "\uf132"
}

export default function (pi: ExtensionAPI) {
  const pane = process.env.HERDR_PANE_ID
  if (!process.env.HERDR_ENV || !pane) return

  const sent = new Map<string, string>()

  // Report a token only when its value changed; failures never reach the user.
  async function report(name: string, value: string | undefined): Promise<void> {
    const key = value ?? ""
    if (sent.get(name) === key) return
    sent.set(name, key)
    const args = ["pane", "report-metadata", pane!, "--source", "pi"]
    args.push(...(value ? ["--token", `${name}=${value}`] : ["--clear-token", name]))
    try {
      await pi.exec("herdr", args, { timeout: REPORT_TIMEOUT_MS })
    } catch {
      sent.delete(name)
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    sent.clear()
    await report("model", ctx.model?.id)
    await report("summary", pi.getSessionName())
    await report("sandbox", sandboxGlyph())
  })

  pi.on("model_select", async (event) => {
    await report("model", event.model.id)
  })

  pi.on("session_info_changed", async (event) => {
    await report("summary", event.name)
  })
}
