#!/usr/bin/env bash
# bootstrap.sh — deploy dotfiles on a new (or existing) machine.
# Idempotent: safe to re-run. Selects packages by session type and OS.
#
#   ./bootstrap.sh            # stow packages for this machine
#   ./bootstrap.sh --dry-run  # show what would be linked, change nothing
#   ./bootstrap.sh --adopt    # first run on a machine that already has configs
#   ./bootstrap.sh --delete   # unstow everything

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

MODE="${1:-install}"

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
        echo "usage: ./bootstrap.sh [--dry-run|--adopt|--delete]"
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
# ~/.para-system. It is a false alarm raised during the unstow half of --restow;
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

stow_tier shared "$DOTFILES/shared" bash git conda gtk systemd ai
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

# ── systemd user timers ──────────────────────────────────────────────────
if command -v systemctl >/dev/null && [[ -d "$HOME/.config/systemd/user" ]]; then
    echo
    echo "── timers ──"
    systemctl --user daemon-reload
    for t in pazras-backup pazras-sync pazras-verify pazras-prune pazras-validate pazras-mirror; do
        systemctl --user enable --now "$t.timer" >/dev/null 2>&1 && echo "  ✓ $t.timer"
    done
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
[[ "$SESSION" == "x11" ]] && echo "   reload i3 with \$mod+Shift+R"
