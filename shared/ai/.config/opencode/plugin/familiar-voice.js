// familiar-voice -- speech in an opencode session (voice-out C6).
//
// OFF BY DEFAULT, PER SESSION. `/voice [on|off|toggle|status]` runs
// `voice-reply` (dotfiles: voice-tts), which keeps the flag; this plugin only
// forwards events to it. `session.idle` pipes the finished reply's text to
// `voice-reply speak`, a new user message cancels the speech in progress.
// Every hook swallows its errors: a voice fault must never break the session.
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";

const flag = (id) =>
  path.join(process.env.XDG_RUNTIME_DIR || "/tmp", "voice-tts", "sessions",
            `opencode-${String(id).replace(/[^A-Za-z0-9._-]/g, "_")}.on`);

// Run voice-reply, optionally feeding stdin; resolves with its stdout, never rejects.
const reply = (cmd, id, input = "") =>
  new Promise((resolve) => {
    try {
      const p = spawn("voice-reply", [cmd, "--harness", "opencode", "--session", String(id)],
                      { stdio: ["pipe", "pipe", "ignore"] });
      let out = "";
      p.stdout.on("data", (d) => (out += d));
      p.stdin.on("error", () => {});
      p.on("error", () => resolve(""));
      p.on("close", () => resolve(out.trim()));
      p.stdin.end(input);
    } catch {
      resolve("");
    }
  });

// Assistant text after the last user message, thinking and tool parts left out.
const lastTurnText = (messages) => {
  const i = messages.map((m) => m.info?.role).lastIndexOf("user");
  return messages.slice(i + 1)
    .filter((m) => m.info?.role === "assistant")
    .flatMap((m) => m.parts ?? [])
    .filter((p) => p.type === "text" && !p.synthetic && !p.ignored && p.text)
    .map((p) => p.text)
    .join("\n\n");
};

export const FamiliarVoice = async ({ client }) => ({
  "command.execute.before": async (input, output) => {
    try {
      if (input.command !== "voice") return;
      const arg = (input.arguments || "").trim() || "toggle";
      const state = ["on", "off", "toggle", "status"].includes(arg)
        ? await reply(arg, input.sessionID)
        : "usage: /voice on|off|toggle|status";
      output.parts = [{
        type: "text",
        text: `Reply with exactly one word, "ok". Do nothing else. (Voice: ${state || "voice-reply failed"}.)`,
      }];
    } catch { /* leave the command as it is */ }
  },

  "chat.message": async (input) => {
    try {
      if (input.sessionID && existsSync(flag(input.sessionID))) await reply("cancel", input.sessionID);
    } catch { /* nothing to cancel */ }
  },

  event: async ({ event }) => {
    try {
      if (event.type !== "session.idle") return;
      const id = event.properties.sessionID;
      if (!existsSync(flag(id))) return;             // off: no request, no process
      const res = await client.session.messages({ path: { id } });
      const text = lastTurnText(res.data ?? []);
      if (text) await reply("speak", id, text);
    } catch { /* a missed reply is not worth a broken session */ }
  },
});
