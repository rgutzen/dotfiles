# AI tooling

Config for the AI coding harnesses in daily use. Curated deliberately — see
"Why so few plugins" below — after auditing actual usage rather than what had
accumulated over time.

## What's in this package

```
.claude/
  settings.json     Claude Code settings: model, hooks, statusline, enabled plugins
  commands/          Custom slash commands
    rse-mode.md      Research Software Engineer mode — the one custom command
                      that survived the audit (52 uses in history; everything
                      else tried once or never)
.config/opencode/
  opencode.json              Core OpenCode config: plugins, model, agent toggles
  oh-my-opencode-slim.json   OMO config: DeepSeek preset, custom skill-specialist
                             agent, disabled agents (designer, council)
```

## Why so few plugins

Claude Code plugins accumulate quietly — installing one is a single command,
so nothing forces a decision about whether it's worth the surface area.
Auditing against `history.jsonl` on 2026-08-26 found a 25-command third-party
framework (`sc:*`, "SuperClaude") with **2 invocations ever**, one of which
was just its own help command. It's gone. Six more plugins were installed
but already disabled and unused (`atomic-agents`, `sourcegraph`,
`security-guidance`, `superpowers`, `example-skills`, `huggingface-skills`) —
also gone.

**What's kept, and why each one earns its place:**

| Plugin | Why |
|---|---|
| `code-review`, `code-simplifier`, `commit-commands`, `github` | Official, maintained, each does one native-feeling thing |
| `claude-md-management`, `claude-code-setup` | Meta-tools for maintaining Claude Code itself |
| `context7` | Live library docs — genuinely can't get this from training data |
| `document-skills` | docx/pptx/xlsx/pdf generation — real, recurring need |
| `claude-api` | Reference for Anthropic API/SDK work |
| `20minds` | Structured decision-making tool, actively used |
| `explanatory-output-style` | On by default — reconsider if the verbosity tax stops being worth it; this is the one entry here that's a standing default rather than an on-demand tool |

`coderabbit` was previously installed but dropped from this curated set — add
it back if you're actively using CodeRabbit reviews.

## claude-flow / `ruflo`

The `ruflo` marketplace (`github.com/ruvnet/ruflo`, ruvnet's later fork of
claude-flow) is registered in `extraKnownMarketplaces` but **nothing is
installed from it**. It's a large, ~35-sub-plugin framework (swarm, sparc,
neural-trader, federation, agentdb, …) — installing all of it would just
reintroduce the bloat this cleanup removed. On the new machine, look at
`plugins/` in the cached marketplace repo and install specifically what's
needed (most likely `ruflo-core` and/or `ruflo-swarm` as the actual
claude-flow orchestration core) — don't bulk-install the marketplace.

For project-scoped use (the pattern already in use in `TradeBot`/`DynVision`),
claude-flow doesn't need a global install at all:

```bash
npx claude-flow@latest init      # run inside a project — creates .claude-flow/
```

## Provider subscriptions

Accounts, not local secrets — the actual API keys/OAuth tokens live in each
harness's own auth store (Claude Code's `.credentials.json`, OpenCode's
`auth-v2.json`, Hermes' own token store), none of which are in this repo or
portable via git. Re-authenticate fresh on the new machine.

- **Anthropic** — primary, used by Claude Code directly and as the default
  model in OpenCode/OMO (`anthropic/claude-sonnet-4-6`)
- **DeepSeek** — OMO's `deepseek` preset; also configured as Hermes' fallback
  model
- **OpenRouter** — secondary routing for models not directly available

## Setup on a new machine

### 1. Claude Code
```bash
curl -fsSL https://claude.ai/install.sh | bash     # or: npm i -g @anthropic-ai/claude-code
claude                                              # first run walks through login
```
`bootstrap.sh` (run from the dotfiles root) stows this package's
`.claude/settings.json` and `.claude/commands/` into place. Plugins install
themselves from `enabledPlugins` the first time Claude Code reads the config;
if any don't auto-install, `/plugin marketplace add <name>` for each entry
under `extraKnownMarketplaces` first.

### 2. OpenCode
```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login          # Anthropic, DeepSeek, OpenRouter — whichever you use
```
`bootstrap.sh` stows `.config/opencode/opencode.json` and
`oh-my-opencode-slim.json` into place. OpenCode reads `opencode.json`'s
`plugin` array and installs `oh-my-opencode-slim` (and the others) on next
run. Note: that array currently has a bare `"list"` entry that doesn't look
like a real package name — check whether that's intentional before relying
on it.

### 3. Hermes
Hermes has its own installer and is **not** part of this dotfiles package —
it manages a systemd gateway service, Signal integration, and its own plugin
set (Lore memory, eagle-eye skill routing, rtk-rewrite). Run its own
`setup-hermes.sh`, then restore `.hermes.md`/project `.lore.md` files from
wherever they're backed up. See `HERMES-SIGNAL-SETUP.md` (in `B_Tech/`, not
this repo — it names a personal phone number, so it stays out of any git
repo) for the Signal-side configuration.

### 4. LM Studio (new machine only)
Local model runner, replacing the stale Ollama setup from the X280 (one
7-month-old model, unused). Install LM Studio, pull a current tool-use-
capable model — don't just carry the old one forward. Relevant if you set up
self-hosted inbox-zero (see `MIGRATION-PLAN.md` §5.5 in `pazras-system`),
which needs a local LLM for triage.

### 5. GPG (recommended alongside the above, for commit signing)
Not currently in use (no `commit.gpgsign` configured), but worth starting
fresh on the new machine while you're already generating new SSH keys:
```bash
gpg --full-generate-key            # choose ed25519/cv25519, not RSA
gpg --list-secret-keys --keyid-format=long
git config --global user.signingkey <key-id>
git config --global commit.gpgsign true
gpg --armor --export <key-id> | gh gpg-key add -
```
Do this on the new machine only — like SSH, a signing key shouldn't travel
from the old one. See `pazras-system/MIGRATION-PLAN.md` §6.1 for the SSH-key
half of this (same "generate fresh, verify, then revoke the old" sequencing
applies to both).
