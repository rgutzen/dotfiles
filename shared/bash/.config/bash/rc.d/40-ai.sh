# AI coding harnesses. Their configs are the shared/ai stow package.

if [ -d "$HOME/.opencode/bin" ]; then
    PATH="$HOME/.opencode/bin:$PATH"
    export PATH
fi
export OPENCODE_DISABLE_EXTERNAL_SKILLS=1
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true   # oh-my-opencode-slim

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
