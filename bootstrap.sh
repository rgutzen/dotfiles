#!/usr/bin/env bash
# bootstrap.sh — deploy dotfiles on a new (or existing) machine.
# Idempotent: safe to re-run. Selects packages by session type.
#
#   ./bootstrap.sh            # stow packages for the current session
#   ./bootstrap.sh --dry-run  # show what would be linked, change nothing
#   ./bootstrap.sh --delete   # unstow everything

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

MODE="${1:-install}"
STOW_ARGS=()
case "$MODE" in
    --dry-run) STOW_ARGS+=(--simulate --verbose) ;;
    --delete)  STOW_ARGS+=(--delete) ;;
esac

command -v stow >/dev/null || {
    echo "✗ GNU stow not found."
    echo "  Debian/Ubuntu: sudo apt install stow"
    echo "  Arch/Omarchy:  sudo pacman -S stow"
    exit 1
}

SHARED=(bash git conda gtk)
case "${XDG_SESSION_TYPE:-x11}" in
    wayland) SESSION=wayland; PKGS=(hypr waybar) ;;
    *)       SESSION=x11;     PKGS=(i3 polybar autorandr) ;;
esac

echo "▸ dotfiles: $DOTFILES"
echo "▸ session:  $SESSION"
echo

echo "── shared ──"
stow "${STOW_ARGS[@]}" -t "$HOME" -d "$DOTFILES/shared" "${SHARED[@]}" && echo "  ✓ ${SHARED[*]}"

echo "── $SESSION ──"
avail=()
for p in "${PKGS[@]}"; do
    # skip placeholder packages that have no content yet (e.g. wayland/ on X280)
    [[ -n "$(find "$DOTFILES/$SESSION/$p" -mindepth 1 -type f 2>/dev/null | head -1)" ]] && avail+=("$p")
done
if ((${#avail[@]})); then
    stow "${STOW_ARGS[@]}" -t "$HOME" -d "$DOTFILES/$SESSION" "${avail[@]}" && echo "  ✓ ${avail[*]}"
else
    echo "  (no populated packages for $SESSION yet)"
fi

[[ "$MODE" == "--delete" || "$MODE" == "--dry-run" ]] && exit 0

# ── machine-local overrides (never tracked) ──────────────────────────────
echo
echo "── local overrides ──"
mkdir -p "$HOME/.config/bash" "$HOME/.config/git"
for f in bash/local.sh git/local; do
    if [[ ! -f "$HOME/.config/$f" ]]; then
        cp "$DOTFILES/secrets.example/$(basename "$f")" "$HOME/.config/$f" 2>/dev/null \
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

echo
echo "✅ bootstrap complete"
[[ "$SESSION" == "x11" ]] && echo "   reload i3 with \$mod+Shift+R"
