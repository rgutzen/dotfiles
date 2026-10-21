/**
 * auto-topic — the session's topic in Pi's footer and terminal title.
 *
 * Pi already renders `cwd • <session name>` in the footer and
 * `π - <session name> - <dir>` in the pane title, so the only work left is
 * naming the session:
 *
 *   1. deterministic — the first prompt becomes the name immediately, no model call
 *   2. refined      — a local model rewrites the same prompt as a short title while
 *                     the agent is still working on it
 *
 * A name set by /name, --name or anything else wins and is never overwritten.
 *
 * Optional config: ${PI_CODING_AGENT_DIR:-~/.pi/agent}/auto-topic.json
 *   { "enabled": true, "refine": true,
 *     "model": "ollama/qwen3:4b-instruct-2507-q4_K_M",
 *     "maxChars": 40, "maxWords": 6 }
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const CUSTOM_TYPE = "auto-topic";

interface Config {
  enabled: boolean;
  refine: boolean;
  model: string;
  maxChars: number;
  maxWords: number;
}

const DEFAULTS: Config = {
  enabled: true,
  refine: true,
  model: "ollama/qwen3:4b-instruct-2507-q4_K_M",
  maxChars: 40,
  maxWords: 6,
};

let cached: Config | undefined;
function config(): Config {
  if (cached) return cached;
  const dir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi/agent");
  try {
    cached = { ...DEFAULTS, ...JSON.parse(readFileSync(join(dir, "auto-topic.json"), "utf8")) };
  } catch {
    cached = DEFAULTS;
  }
  return cached;
}

/** Cut at a word boundary so the title never ends mid-word. */
function clip(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const space = cut.lastIndexOf(" ");
  return (space > max / 3 ? cut.slice(0, space) : cut).replace(/[.,;:]$/, "") + "…";
}

/** First meaningful line of the prompt, markdown noise removed. */
function deriveTopic(raw: string): string | undefined {
  const line = raw
    .split("\n")
    .map((l) => l.trim())
    .find((l) => l && !l.startsWith("```"));
  if (!line) return undefined;
  return clip(line.replace(/`/g, "").replace(/\s+/g, " ").trim(), config().maxChars);
}

/** Model output as a title: no quotes, no label prefix, bounded. */
function sanitize(raw: string, maxChars: number, maxWords: number): string | undefined {
  let text = (raw.split("\n").find((l) => l.trim()) ?? "")
    .replace(/^\s*(?:session\s+)?(?:title|topic)\s*:\s*/i, "")
    .replace(/^["'`*#\s]+|["'`*\s]+$/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return undefined;
  const words = text.split(" ");
  if (words.length > maxWords) text = words.slice(0, maxWords).join(" ");
  text = clip(text, maxChars);
  return text.replace(/[.,;:!?]+$/, "");
}

/** The first real user prompt, which is what the topic describes. */
function firstUserText(ctx: ExtensionContext): string | undefined {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type !== "message" || entry.message.role !== "user") continue;
    const content = entry.message.content;
    const text =
      typeof content === "string"
        ? content
        : content
            .filter((part) => part.type === "text")
            .map((part) => (part as { text: string }).text)
            .join(" ");
    if (text.trim()) return text.trim().slice(0, 1200);
  }
  return undefined;
}

export default function (pi: ExtensionAPI) {
  const cfg = config();
  if (!cfg.enabled) return;

  let mine: string | undefined; // the name this extension last wrote
  let refined = false; // already rewritten by the model in this session
  let attempts = 0; // model calls, capped so a dead model cannot retry forever

  /** Recover ownership after reload, resume or fork. */
  pi.on("session_start", (_event, ctx) => {
    mine = undefined;
    refined = false;
    const current = pi.getSessionName();
    if (!current) return;
    const branch = ctx.sessionManager.getBranch();
    for (let i = branch.length - 1; i >= 0; i--) {
      const entry = branch[i];
      if (entry?.type !== "custom" || entry.customType !== CUSTOM_TYPE) continue;
      const data = entry.data as { name?: string; refined?: boolean } | undefined;
      if (data?.name === current) {
        mine = current;
        refined = data.refined === true;
      }
      return;
    }
  });

  /** Any name change we did not make means a human owns the name now. */
  pi.on("session_info_changed", (event) => {
    if (event.name !== mine) mine = undefined;
  });

  pi.on("input", (event, ctx) => {
    if (event.source !== "interactive") return;
    const text = event.text.trim();
    if (!text || /^[/!$]/.test(text)) return; // commands are not topics
    if (pi.getSessionName()) return; // /name, --name or this extension already named it
    const topic = deriveTopic(event.text);
    if (!topic) return;
    mine = topic;
    pi.setSessionName(topic);
    pi.appendEntry(CUSTOM_TYPE, { name: topic, refined: false });
    if (cfg.refine) {
      attempts++;
      void refine(text, ctx, cfg).catch(() => {});
    }
  });

  /** Retry once if the model was unreachable when the prompt arrived. */
  pi.on("agent_settled", (_event, ctx) => {
    if (!cfg.refine || refined || attempts >= 2) return;
    if (!mine || pi.getSessionName() !== mine) return;
    const prompt = firstUserText(ctx);
    if (!prompt) return;
    attempts++;
    void refine(prompt, ctx, cfg).catch(() => {});
  });

  async function refine(prompt: string, ctx: ExtensionContext, c: Config): Promise<void> {
    const slash = c.model.indexOf("/");
    const provider = slash > 0 ? c.model.slice(0, slash) : "ollama";
    const modelId = slash > 0 ? c.model.slice(slash + 1) : c.model;
    const model = ctx.modelRegistry.find(provider, modelId);
    if (!model) return;

    const result = await ctx.modelRegistry.complete(
      model,
      {
        systemPrompt:
          `Rewrite the session's first prompt as a topic of at most ${c.maxWords} words. ` +
          "Reply with the topic only: no quotes, no trailing punctuation, no explanation.",
        messages: [{ role: "user", content: prompt, timestamp: Date.now() }],
      },
      { maxTokens: 32, temperature: 0.2, signal: AbortSignal.timeout(20_000) },
    );

    const text = result.content
      .filter((part) => part.type === "text")
      .map((part) => (part as { text: string }).text)
      .join(" ");
    const title = sanitize(text, c.maxChars, c.maxWords);
    if (!title) return;
    if (pi.getSessionName() !== mine) return; // renamed while the model was thinking
    mine = title;
    refined = true;
    pi.setSessionName(title);
    pi.appendEntry(CUSTOM_TYPE, { name: title, refined: true });
  }
}
