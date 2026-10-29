#!/usr/bin/env bash
# voice-stop.sh -- Claude Code hook for UserPromptSubmit and Stop (voice-out C6).
#
# Thin on purpose: it runs in EVERY Claude Code session, so with speech off it
# must exit 0 within a few milliseconds and without starting python. The work
# (the /voice command, cancel, reading the transcript, speaking) is
# `voice-reply claude-hook`. No path here exits non-zero, none blocks a reply.
dir="${XDG_RUNTIME_DIR:-/tmp}/voice-tts/sessions"
in="$(cat 2>/dev/null)" || exit 0

# Off everywhere and not a /voice command: nothing to do.
if ! compgen -G "$dir/claude-*.on" >/dev/null 2>&1 && [[ $in != *'/voice'* ]]; then
    exit 0
fi

vr="$(command -v voice-reply 2>/dev/null)" || vr="$HOME/.local/bin/voice-reply"
[[ -x $vr ]] || exit 0
printf '%s' "$in" | "$vr" claude-hook 2>/dev/null || true
exit 0
