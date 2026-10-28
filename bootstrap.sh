#!/usr/bin/env bash
# bootstrap.sh — deploy dotfiles on a new (or existing) machine.
# Idempotent: safe to re-run. Selects packages by session type and OS.
#
#   ./bootstrap.sh            # stow packages for this machine
#   ./bootstrap.sh --dry-run  # show what would be linked, change nothing
#   ./bootstrap.sh --adopt    # first run on a machine that already has configs
#   ./bootstrap.sh --delete   # unstow everything
#   ./bootstrap.sh --voice    # also build the voice-tts venv, download its
#                             # 338 MB of model weights, enable the service
#                             # (combines with install: ./bootstrap.sh --adopt --voice)

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

# --voice is a switch beside the mode, not a mode: it runs voice-tts-setup, which
# downloads 338 MB, so a plain re-run never does.
MODE=install
VOICE=0
for arg in "$@"; do
    case "$arg" in
        --voice) VOICE=1 ;;
        *)       MODE="$arg" ;;
    esac
done

# --no-folding on every package, deliberately.
#
# Stow's default is "tree folding": when a target directory doesn't exist yet it
# links the whole directory in one go, so ~/.config/foo becomes a symlink into
# this repo. Anything the *application* then writes into that directory lands
# inside git. That is not hypothetical — it is why gtk-3.0/{bookmarks,servers}
# are tracked here (GTK wrote them through a folded link), and on a fresh
# machine it would put systemd's timers.target.wants/ symlinks in the repo the
# moment the timer section below runs.
#
# Cost: a file newly added to a package needs a re-run to show up in $HOME,
# where folding would have surfaced it immediately. Cheap — this script is
# idempotent, so just re-run it.
# --ignore=node_modules: shared/ai/.opencode/node_modules/ exists in the working
# tree (gitignored) because OpenCode wrote it there through a folded link — the
# same hazard --no-folding closes. Never try to deploy it back out.
STOW_ARGS=(--no-folding --ignore='node_modules')

case "$MODE" in
    install)
        # --restow (delete + stow) also converts already-folded directories
        # from previous runs into per-file links, and clears links left behind
        # by files that have since been renamed or removed.
        STOW_ARGS+=(--restow)
        ;;
    --dry-run)
        STOW_ARGS+=(--simulate --verbose)
        ;;
    --delete)
        STOW_ARGS=(--delete --ignore='node_modules')
        ;;
    --adopt)
        # --adopt resolves "target already exists" by moving the existing file
        # INTO the package (overwriting this repo's copy) and symlinking it
        # back. Standalone that is destructive, which is why it is off by
        # default. In a *clean* git tree it is the opposite: every adopted file
        # arrives as an unstaged diff and git becomes the resolution UI —
        # keep-mine, take-theirs and merge-by-hunk all fall out of it.
        #
        # The clean-tree check below is the entire safety mechanism. Without it
        # you cannot tell adopted content from your own uncommitted edits.
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "✗ --adopt needs a clean working tree."
            echo "  Adopted files arrive as unstaged changes; your own uncommitted"
            echo "  work would be indistinguishable from them."
            echo "  Commit or stash first, then re-run."
            exit 1
        fi
        STOW_ARGS+=(--adopt)
        ;;
    *)
        echo "usage: ./bootstrap.sh [--dry-run|--adopt|--delete] [--voice]"
        exit 1
        ;;
esac

command -v stow >/dev/null || {
    echo "✗ GNU stow not found."
    echo "  Debian/Ubuntu: sudo apt install stow"
    echo "  Arch/Omarchy:  sudo pacman -S stow"
    exit 1
}

# A package is deployable only if it holds at least one real file; empty
# placeholders (wayland/hypr before Omarchy is set up) are skipped silently.
populated() { [[ -n "$(find "$1" -mindepth 1 -type f 2>/dev/null | head -1)" ]]; }

# GNU stow 2.3.1 (Ubuntu 22.04's version) has a known bug, fixed upstream, that
# prints "BUG in find_stowed_path? Absolute/relative mismatch" once per absolute
# symlink it meets while scanning the target tree — on the X280 that is
# the ~/.local/bin/familiar symlink. It is a false alarm raised during the unstow half of --restow;
# the links are still made correctly. Drop that one line, keep everything else
# stow says, and keep its exit status.
run_stow() {
    local out rc
    set +e; out="$(stow "$@" 2>&1)"; rc=$?; set -e
    [[ -n "$out" ]] && printf '%s\n' "$out" \
        | grep -v '^BUG in find_stowed_path? Absolute/relative mismatch' || true
    return $rc
}

# stow_tier <label> <dir> <pkg>...
# Package lists stay explicit rather than globbed: shared/theme/ is a generator
# with its own script and schemes, not a stow package, and globbing would link
# apply-theme.sh into $HOME.
#
# The same package name may appear in several tiers — shared/bash, ubuntu/bash,
# arch/bash and x11/bash all exist. They are distinct packages in distinct stow
# directories that deposit different files into one ~/.config/bash/{env,rc}.d/,
# which ~/.bashrc then composes. No file is written by two packages, so they
# merge rather than conflict. This only works with --no-folding: with tree
# folding the first package to run would claim rc.d/ as a single directory
# symlink and the next would collide.
stow_tier() {
    local label="$1" dir="$2"; shift 2
    [[ -d "$dir" ]] || return 0
    local p avail=()
    for p in "$@"; do populated "$dir/$p" && avail+=("$p"); done
    echo "── $label ──"
    if ((${#avail[@]})); then
        run_stow "${STOW_ARGS[@]}" -t "$HOME" -d "$dir" "${avail[@]}" && echo "  ✓ ${avail[*]}"
    else
        echo "  (no populated packages for $label yet)"
    fi
}

case "${XDG_SESSION_TYPE:-x11}" in
    wayland) SESSION=wayland; SESSION_PKGS=(hypr waybar bash) ;;
    *)       SESSION=x11;     SESSION_PKGS=(i3 polybar autorandr wm-scripts bash) ;;
esac

# OS tier, kept separate from the session tier on purpose. Omarchy is Arch *and*
# Wayland, but its pacman scripts and distro defaults are an Arch concern — they
# apply in a bare TTY, and Hyprland-on-Ubuntu would want the wayland tier with
# none of them. Session type and distro are independent axes, so they get
# independent tiers.
OS_TIER=""; OS_PKGS=()
[[ -f /etc/debian_version ]] && { OS_TIER=ubuntu; OS_PKGS=(os-scripts bash); }
[[ -f /etc/arch-release   ]] && { OS_TIER=arch;   OS_PKGS=(os-scripts bash); }

echo "▸ dotfiles: $DOTFILES"
echo "▸ session:  $SESSION"
echo "▸ os:       ${OS_TIER:-(unrecognised — OS tier skipped)}"
echo

stow_tier shared "$DOTFILES/shared" bash zsh git conda gtk systemd ai inbox-zero proton bin starship easyeffects herdr nvim lazygit voxtype voice-tts wireplumber
stow_tier "$SESSION" "$DOTFILES/$SESSION" "${SESSION_PKGS[@]}"
[[ -n "$OS_TIER" ]] && stow_tier "$OS_TIER" "$DOTFILES/$OS_TIER" "${OS_PKGS[@]}"

[[ "$MODE" == "--delete" || "$MODE" == "--dry-run" ]] && exit 0

if [[ "$MODE" == "--adopt" ]]; then
    echo
    echo "── adopted ──"
    if git diff --quiet; then
        echo "  nothing to review — no target file differed from the repo."
    else
        git diff --stat
        echo
        echo "  Everything above is what THIS MACHINE had. Resolve before committing:"
        echo "    git diff                  # review"
        echo "    git checkout -- <file>    # keep the repo's version"
        echo "    git checkout -p <file>    # merge hunk by hunk"
        echo "    (leave as-is)             # keep this machine's version"
        echo
        echo "  Then re-run ./bootstrap.sh for the theme and timer steps."
    fi
    exit 0
fi

# ── machine-local overrides (never tracked) ──────────────────────────────
echo
echo "── local overrides ──"
mkdir -p "$HOME/.config/bash" "$HOME/.config/git"
for f in bash/local.sh:local.sh git/local:git; do
    tpl="${f#*:}"; f="${f%%:*}"
    if [[ ! -f "$HOME/.config/$f" ]]; then
        cp "$DOTFILES/secrets.example/$tpl" "$HOME/.config/$f" 2>/dev/null \
            && echo "  + created ~/.config/$f from template — fill in from Proton Pass" \
            || echo "  ! no template for $f"
    else
        echo "  ✓ ~/.config/$f exists"
    fi
done

# ── theme ────────────────────────────────────────────────────────────────
echo
echo "── theme ──"
if command -v tinted-builder-rust >/dev/null; then
    ./shared/theme/apply-theme.sh >/dev/null && echo "  ✓ thrifted-rug applied"
else
    echo "  ! tinted-builder-rust missing — run: cargo install tinted-builder-rust --locked"
    echo "    then: ./shared/theme/apply-theme.sh"
fi

# Herdr has no config include: config.toml is config.toml.base plus a
# [theme.custom] block derived from the active Omarchy palette. Stowing alone
# leaves no config.toml at all, so generate it here too.
HERDR_THEME_HOOK="$HOME/.config/omarchy/hooks/theme-set.d/20-herdr.sh"
if [[ -x "$HERDR_THEME_HOOK" ]]; then
    "$HERDR_THEME_HOOK" "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo unknown)" >/dev/null \
        && echo "  ✓ herdr palette generated" \
        || echo "  ! herdr palette generation failed"
fi

# ── service-owned config ─────────────────────────────────────────────────
echo
echo "── voice ──"
# Voxtype writes its own config.toml (seen at the 2026-10-24 daemon start: a
# whole-file serialisation, comments reordered, a .bak beside it), so
# shared/voxtype/.stow-local-ignore keeps it out of stow — a symlink would
# write that serialisation into this public repository. The tracked file is the
# seed, applied only where the machine has none.
VOXTYPE_SEED="$DOTFILES/shared/voxtype/.config/voxtype/config.toml"
VOXTYPE_CONF="$HOME/.config/voxtype/config.toml"
if [[ -f "$VOXTYPE_SEED" && ! -e "$VOXTYPE_CONF" ]]; then
    mkdir -p "$(dirname "$VOXTYPE_CONF")"
    cp "$VOXTYPE_SEED" "$VOXTYPE_CONF" && echo "  + seeded ~/.config/voxtype/config.toml"
else
    echo "  ✓ voxtype config.toml is voxtype's own"
fi

# voice-tts needs a venv and 338 MB of model weights, so it is built only on
# request. The stow step above has already linked the script into ~/.local/bin.
# A dry run passes its flag on, and --delete never builds anything.
if [[ "$VOICE" == 1 && "$MODE" == --dry-run ]]; then
    "$DOTFILES/shared/voice-tts/.local/bin/voice-tts-setup" --dry-run
elif [[ "$VOICE" == 1 && "$MODE" != --delete ]]; then
    "$DOTFILES/shared/voice-tts/.local/bin/voice-tts-setup" \
        || echo "  ! voice-tts-setup failed"
elif [[ "$MODE" != --delete ]]; then
    if [[ -x "$HOME/.local/share/voice-tts/venv/bin/python" \
          && -f "$HOME/.local/share/voice-tts/models/kokoro-v1.0.onnx" ]]; then
        echo "  ✓ voice-tts venv and models present (--voice re-checks them)"
    else
        echo "  ! voice-tts service not set up — run ./bootstrap.sh --voice (or voice-tts-setup)"
    fi
fi

# ── agent integrations ───────────────────────────────────────────────────
# Herdr owns these files (it writes them into each harness's own config dir),
# so they are not stowed. Re-installing is idempotent and also upgrades an
# outdated integration version.
echo
echo "── agent integrations ──"
if command -v herdr >/dev/null; then
    if herdr integration install pi >/dev/null 2>&1; then
        echo "  ✓ herdr integration: pi"
    else
        echo "  ! herdr integration: pi failed"
    fi
else
    echo "  ! herdr missing — https://herdr.dev"
fi

# ── systemd user timers ──────────────────────────────────────────────────
# The enable list used to be hardcoded here, a second copy of a fact that
# already lives in PAZRAS_TIMERS (06_SYSTEM/engine/structure/pazras-master-
# config.sh) — the same hardcoded-list drift pazras-healthcheck now audits
# for (agents/knowledge/system/schedule/scheduled-processes.md). It had already
# silently fallen behind: pazras-memory, pazras-lore-sync and pazras-reconcile
# were enabled by hand and never added here. Source the config instead so
# there is exactly one place a new scheduled process gets registered.
if command -v systemctl >/dev/null && [[ -d "$HOME/.config/systemd/user" ]]; then
    echo
    echo "── timers ──"
    systemctl --user daemon-reload
    PAZRAS_CONFIG="$HOME/06_SYSTEM/config/structure/pazras-master-config.sh"
    if [[ -f "$PAZRAS_CONFIG" ]]; then
        # shellcheck disable=SC1090
        source "$PAZRAS_CONFIG" >/dev/null 2>&1
        for t in $(get_timer_units 2>/dev/null); do
            systemctl --user enable --now "$t.timer" >/dev/null 2>&1 && echo "  ✓ $t.timer"
        done
    else
        echo "  ! $PAZRAS_CONFIG not found — skipping (is 06_SYSTEM checked out?)"
    fi
    # inbox-zero.service: not a timer, just a boot-time `docker compose up -d`
    # (containers already carry restart: always, so this mainly matters after
    # a full reboot). Only enable it if ~/.inbox-zero/.env exists — the compose
    # stack fails fast without real secrets, and .env is deliberately never
    # created by this script (see .env.example in the inbox-zero package).
    if [[ -f "$HOME/.inbox-zero/.env" ]]; then
        systemctl --user enable --now inbox-zero.service >/dev/null 2>&1 && echo "  ✓ inbox-zero.service"
    fi
    # voice-selection-watch.service: records when the primary selection and the
    # clipboard last changed, so `speak-selection` (SUPER+ALT+L) speaks the newer
    # one instead of whichever it happens to prefer. Its only prerequisite is
    # wl-clipboard and a Wayland session; without the session `enable` still
    # works and the unit starts at the next login. voice-tts.service is NOT
    # enabled here: it needs a venv and 338 MB of model weights, which
    # `./bootstrap.sh --voice` (voice-tts-setup) creates and then enables the
    # unit itself (see memory/knowledge/system/harness/voice-local.md).
    if command -v wl-paste >/dev/null && [[ "$SESSION" == "wayland" ]]; then
        systemctl --user enable voice-selection-watch.service >/dev/null 2>&1 \
            && echo "  ✓ voice-selection-watch.service"
    fi
    # pazras-archive-flush.path is deliberately NOT enabled. The flush moves
    # data out of 05_ARCHIVES onto BigFish, where 05_ARCHIVES-EXTERNAL is still
    # single-copy (the archives-external restic repo waits on Disk B). An
    # automatic trigger means that move happens unattended and unreviewed;
    # until there is a second copy, run it deliberately instead:
    #
    #     systemctl --user start pazras-archive-flush.service
    #
    # To restore the automatic behaviour:
    #     systemctl --user enable --now pazras-archive-flush.path
    systemctl --user is-enabled pazras-archive-flush.path >/dev/null 2>&1 \
        && echo "  ! pazras-archive-flush.path is enabled (expected: manual only)"
fi

echo
echo "✅ bootstrap complete"
# `if`, not a trailing `&&` list: under `set -e` a false test on the script's
# LAST line becomes the script's exit status, so every wayland run ended in 1.
if [[ "$SESSION" == "x11" ]]; then
    echo "   reload i3 with \$mod+Shift+R"
fi
