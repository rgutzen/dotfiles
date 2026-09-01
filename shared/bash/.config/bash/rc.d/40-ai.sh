# AI coding harnesses. Their configs are the shared/ai stow package.

if [ -d "$HOME/.opencode/bin" ]; then
    PATH="$HOME/.opencode/bin:$PATH"
    export PATH
fi
export OPENCODE_DISABLE_EXTERNAL_SKILLS=1
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true   # oh-my-opencode-slim

# Lore pins every provider's baseURL to its gateway; the gateway only routes
# known providers upstream. Without this, local-ollama requests fall back to
# OpenAI and fail with "Incorrect API key provided: local-ollama".
export LORE_UPSTREAM_LOCAL_OLLAMA=http://localhost:11434/v1

# Lore's background workers (distill/curator) resolve their provider from a
# bare model name defaulting to `anthropic`, while this machine's sessions
# authenticate to deepseek — the lookup misses and both workers fail closed
# with `no-auth`. Pin the worker model to the credential actually stored.
# NB: this breaks again on an anthropic-only session; see lore.log:1116.
export LORE_WORKER_MODEL=deepseek/deepseek-v4-flash

# Lore's SQLite DB, relocated out of ~/.local/share (which is in NO backup path).
# It holds the project memory of every repo; before the first move it was a
# single copy on a single disk. Moved again 2026-09-01 from 02_AREAS/B_Tech/ai
# to 06_SYSTEM/agents, restic's zettel-system repo (small, high-value, daily,
# fully verified — same tier as .claude) rather than the weekly PARA sweep.
#
# MUST BE SET FOR EVERY lore INVOCATION. `dbPath()` falls back to
# ~/.local/share/lore/lore.db when unset, so a shell that misses this file
# silently opens a SECOND, empty database rather than failing loudly.
#
# The DB holds bearer credentials (Supabase auth session / refresh token in
# team_config). lore chmods the *file* 0600 on any path, but only chmods the
# *directory* 0700 on its default path — so the directory is set 0700 by hand
# and covered by a no-read rule for remote models in agents/BOUNDARIES.yaml.
export LORE_DB_PATH="$HOME/06_SYSTEM/agents/loredb/lore.db"

[ -f "$HOME/.openclaw/completions/openclaw.bash" ] \
    && . "$HOME/.openclaw/completions/openclaw.bash"

# Local Ollama models via Hermes, with a trimmed toolset/prompt.
# Hermes' default toolset (computer_use, browser-use, tts, memory, etc. —
# ~55KB of tool-schema JSON) plus AGENTS.md/skills/memory injection adds
# ~20k fixed prompt tokens to every turn; on the iGPU's local models that's
# minutes of prefill before any reply. `--ignore-rules -t file,terminal`
# cuts it to ~5k tokens (confirmed: 4+ min -> ~14s per turn).
alias hermes-fast='hermes --ignore-rules -t file,terminal -m qwen-fast'
alias hermes-think='hermes --ignore-rules -t file,terminal -m qwen-thinking'
