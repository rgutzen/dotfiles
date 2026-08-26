# AI tooling

Config for the AI coding harnesses in daily use. Curated deliberately — see
"Why so few plugins" below — after auditing actual usage rather than what had
accumulated over time.

## What's in this package

```
.claude/
  settings.json     Claude Code settings: model, hooks, statusline, enabled plugins
  commands/
    rse-mode.md      Research Software Engineer mode — the one custom command
                      that survived the audit (52 uses in history; everything
                      else tried once or never)
  powerline/
    claude-powerline.json   Statusline theme (Thrifted Rug colours). Tracked
                      because settings.json's statusLine command points at it —
                      an untracked file referenced from a tracked one is a
                      config that silently degrades on a new machine.
.config/opencode/
  opencode.json              Core OpenCode config: plugins, model, agent toggles
  oh-my-opencode-slim.json   OMO config: DeepSeek preset, custom skill-specialist
                             agent, disabled agents (designer, council)
```

## What is deliberately *not* here

**The plugins themselves.** Everything in the table below is a marketplace
plugin cloned from GitHub — ~360 MB of upstream git repos under
`~/.claude/plugins/{cache,marketplaces}/`. The tracked artifact is the
*manifest*, not the payload: `enabledPlugins` + `extraKnownMarketplaces` in
`settings.json` is what reinstalls them. Vendoring the payload would fork
someone else's repo into this one and put `/plugin update` in conflict with the
working tree — the `package.json` / `node_modules` split, applied to Claude Code.

One consequence worth knowing: `enabledPlugins` records *names, not versions*.
`~/.claude/plugins/installed_plugins.json` does hold a `gitCommitSha` per
plugin, but that is machine state, not a lockfile — a new machine gets HEAD of
each marketplace. Fine for this set; just not a reproducibility guarantee.

**Dippy.** The `PreToolUse` hook points at
`~/04_RESOURCES/Templates/Dippy/bin/dippy-hook`, which is the entry point of a
Python package with its own `src/` tree — a program, not a dotfile. The hook
command is guarded (`[ -x "$D" ] && exec "$D"; exit 0`) so a machine without
Dippy installed gets a silent no-op rather than an error on every Bash call.

## Why so few plugins

Claude Code plugins accumulate quietly — installing one is a single command,
so nothing forces a decision about whether it's worth the surface area.
Auditing against `history.jsonl` on 2026-08-26 found a 25-command third-party
framework (`sc:*`, "SuperClaude") with **2 invocations ever**, one of which
was just its own help command. It was removed from `enabledPlugins`. Six more were
installed but already disabled and unused (`atomic-agents`, `sourcegraph`,
`security-guidance`, `superpowers`, `example-skills`, `huggingface-skills`) —
also dropped from `enabledPlugins`.

**Dropped ≠ uninstalled.** Removing an entry from `enabledPlugins` stops the
plugin loading; it does not delete it. On the X280 all seven are still in
`installed_plugins.json` and still on disk (`atomic-agents` 13M,
`huggingface-skills` 7.2M, `superpowers` 4.5M, `security-guidance` 932K,
`coderabbit` 156K, `sourcegraph` 84K), alongside `~/.claude/skills_backup/`
(184 dirs, 21M) and `~/.claude/plugins_backup/` (95M) from an earlier cleanup.
Use `/plugin uninstall <name>` to reclaim the space. None of this follows to a
new machine — Omarchy starts from the manifest and installs only what is
enabled.

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

Order matters: **install each harness first, then deploy.** Claude Code and
OpenCode both write a default config on first run, and stow will not overwrite a
real file — so a deploy that runs before they exist links cleanly, while one that
runs after needs `./bootstrap.sh --adopt` (see the repo README). Either works;
knowing which you are in saves a confusing `would cause conflicts` abort.

Nothing here needs the plugins to be copied across — `settings.json` carries the
manifest and Claude Code reinstalls from it.

### 1. Claude Code
```bash
curl -fsSL https://claude.ai/install.sh | bash     # or: npm i -g @anthropic-ai/claude-code
claude                                              # first run walks through login
```
Then, from the dotfiles root:

```bash
./bootstrap.sh --dry-run     # ~/.claude/settings.json will collide if claude ran
./bootstrap.sh               #   ...or --adopt if it did, then resolve the diff
```

That links `.claude/settings.json`, `.claude/commands/` and
`.claude/powerline/claude-powerline.json`. Plugins install themselves from
`enabledPlugins` the next time Claude Code reads the config; if any don't
auto-install, `/plugin marketplace add <name>` for each entry under
`extraKnownMarketplaces` first, then restart.

Two things this deploy does *not* bring, both by design:

- **Dippy** (the `PreToolUse` hook) lives in `04_RESOURCES/Templates/`. Its
  absence is a silent no-op, so the statusline and hooks still work without it —
  install it separately if you want it back.
- **Credentials.** `~/.claude/.credentials.json` is not in this repo. Run
  `claude` and log in.

### 2. OpenCode
```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login          # Anthropic, DeepSeek, OpenRouter — whichever you use
```
`bootstrap.sh` stows `.config/opencode/opencode.json` and
`oh-my-opencode-slim.json` into place. OpenCode reads `opencode.json`'s
`plugin` array and installs `oh-my-opencode-slim` (and the others) on next run.

Two things to check on the new machine:

- `opencode.json`'s `plugin` array has a bare `"list"` entry that doesn't look
  like a real package name — confirm it's intentional before relying on it.
- `oh-my-opencode-slim.json` sets `acpAgents.hermes.env.PATH` to
  `$HOME/.local/bin:$HOME/.hermes/bin:...`. If OpenCode passes that env straight
  to `execve` rather than through a shell, `$HOME` won't expand and `hermes`
  won't be found. If `@hermes` fails to start, deleting the whole `env` key is
  the fix — the agent then inherits OpenCode's environment, which already has
  the right `PATH` from `.bashrc`.

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
