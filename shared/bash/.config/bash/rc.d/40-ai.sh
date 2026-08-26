# AI coding harnesses. Their configs are the shared/ai stow package.

if [ -d "$HOME/.opencode/bin" ]; then
    PATH="$HOME/.opencode/bin:$PATH"
    export PATH
fi
export OPENCODE_DISABLE_EXTERNAL_SKILLS=1
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true   # oh-my-opencode-slim

[ -f "$HOME/.openclaw/completions/openclaw.bash" ] \
    && . "$HOME/.openclaw/completions/openclaw.bash"
