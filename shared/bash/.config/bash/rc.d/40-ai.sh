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

# `pi` picks its billing profile from the directory. The nearest `.pi-profile`
# at or above $PWD names a profile; `pi` then runs `pi-<profile>` (see
# pi-profile). The marker lives in the work tree, so no company name enters
# these dotfiles. `command pi` bypasses it, and the sandbox below with it.
pi() {
    local dir="$PWD" profile
    while [ "$dir" != / ]; do
        if [ -r "$dir/.pi-profile" ]; then
            read -r profile < "$dir/.pi-profile"
            if command -v "pi-$profile" >/dev/null 2>&1; then
                familiar boundaries sandbox run -- "pi-$profile" "$@"
                return
            fi
            echo "pi: $dir/.pi-profile names '$profile', but pi-$profile is not installed; running personal pi" >&2
            break
        fi
        dir="${dir%/*}"; [ -z "$dir" ] && dir=/
    done
    familiar boundaries sandbox run -- pi "$@"
}

# Every harness starts under the bwrap sandbox: the deny rules of
# config/boundaries/ become mounts, which no spelling of a path gets past
# (06_SYSTEM dev/boundary-enforcement 5d). The launcher execs the binary from
# PATH, so these functions are not re-entered. FAMILIAR_NO_SANDBOX=1 is the
# hatch; `familiar boundaries sandbox status` says which one a session got.
claude()   { familiar boundaries sandbox run -- claude "$@"; }
opencode() { familiar boundaries sandbox run -- opencode "$@"; }
hermes()   { familiar boundaries sandbox run -- hermes "$@"; }
