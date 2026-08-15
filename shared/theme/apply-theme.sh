#!/usr/bin/env bash
# apply-theme.sh — build & install the Thrifted Rug theme across applications
#
#   ./apply-theme.sh              # build + install for the current session
#   ./apply-theme.sh --check      # build only, report drift, install nothing
#   ./apply-theme.sh --sync       # update cached template repos first
#
# ARCHITECTURE
#   schemes/base24/thrifted-rug.yaml  is the SINGLE SOURCE OF TRUTH.
#   schemes/base16/thrifted-rug.yaml  is GENERATED from it (base00-base0F subset)
#     so that the many base16-only templates in the ecosystem can consume it.
#   Every application config is a GENERATED VIEW of that scheme, rendered by
#   tinted-builder-rust from the official tinted-theming mustache templates.
#
# WHY NOT `tinty apply`?
#   tinty's scheme registry only resolves schemes from the official schemes
#   repo; a custom scheme is not reachable from `tinty apply` (verified
#   2026-08-16: "Scheme does not exist"). The standalone builder takes
#   --schemes-dir explicitly, so it works with our own scheme directly.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

THEME=thrifted-rug
SCHEMES_DIR="$PWD/schemes"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/tinted-templates"
MODE="${1:-install}"

command -v tinted-builder-rust >/dev/null || {
    echo "✗ tinted-builder-rust not found. Install: cargo install tinted-builder-rust --locked" >&2
    exit 1
}

# --- template manifest ---------------------------------------------------
# repo | built-output-glob | destination | sessions(all|x11|wayland)
TEMPLATES=(
  "base16-i3|colors/*${THEME}*|$HOME/.config/i3/colors.config|x11"
  "base16-polybar|colors/*${THEME}*|$HOME/.config/polybar/colors.ini|x11"
  "base16-waybar|colors/*${THEME}*|$HOME/.config/waybar/colors.css|wayland"
  "base16-rofi|*/*${THEME}*|$HOME/.config/rofi/colors.rasi|x11"
  "base16-dunst|themes/*${THEME}*|$HOME/.config/dunst/colors|all"
  "base16-gtk-flatcolor|gtk-3/*${THEME}*|$HOME/.config/gtk-3.0/colors.css|all"
)

session() { [[ "${XDG_SESSION_TYPE:-x11}" == "wayland" ]] && echo wayland || echo x11; }
SESSION=$(session)
echo "▸ scheme:  base24-$THEME   (base16 fallback generated)"
echo "▸ session: $SESSION"
echo

# --- regenerate the base16 subset from the base24 source of truth --------
python3 - "$SCHEMES_DIR" "$THEME" <<'PY'
import re, sys, pathlib
d, theme = pathlib.Path(sys.argv[1]), sys.argv[2]
src = d/"base24"/f"{theme}.yaml"
cols = dict(re.findall(r'(base[0-9A-F]{2}):\s*"(#[0-9a-f]{6})"', src.read_text()))
meta = {k: re.search(rf'^{k}:\s*"(.*)"', src.read_text(), re.M) for k in ("name","author","variant")}
out = ['system: "base16"']
out += [f'{k}: "{m.group(1)}"' for k,m in meta.items() if m]
out += ['# GENERATED from base24/%s.yaml by apply-theme.sh — DO NOT EDIT' % theme, 'palette:']
out += [f'  base{i:02X}: "{cols["base%02X" % i]}"' for i in range(16)]
(d/"base16"/f"{theme}.yaml").write_text("\n".join(out)+"\n")
PY
echo "✓ base16 subset regenerated from base24 source"

mkdir -p "$CACHE"
drift=0

for entry in "${TEMPLATES[@]}"; do
    IFS='|' read -r repo glob dest sessions <<< "$entry"
    [[ "$sessions" != "all" && "$sessions" != "$SESSION" ]] && continue

    dir="$CACHE/$repo"
    if [[ ! -d "$dir" ]]; then
        git clone -q --depth 1 "https://github.com/tinted-theming/$repo.git" "$dir" 2>/dev/null || {
            echo "  ⚠ $repo — clone failed, skipping"; continue; }
    elif [[ "$MODE" == "--sync" ]]; then
        git -C "$dir" pull -q --ff-only 2>/dev/null || true
    fi

    tinted-builder-rust build --schemes-dir "$SCHEMES_DIR" "$dir" >/dev/null 2>&1 || {
        echo "  ⚠ $repo — build failed, skipping"; continue; }

    built=$(compgen -G "$dir/$glob" 2>/dev/null | head -1) || true
    [[ -z "${built:-}" ]] && { echo "  ⚠ $repo — no output matching '$glob'"; continue; }

    # i3 4.20.1 has no `include` directive (added in 4.21) — splice the
    # generated `set $baseXX` lines between markers in the config instead.
    if [[ "$repo" == "base16-i3" && -f "$HOME/.config/i3/config" ]]; then
        python3 - "$built" "$HOME/.config/i3/config" <<'INJECT'
import sys, pathlib, re
colours = pathlib.Path(sys.argv[1]).read_text()
cfg = pathlib.Path(sys.argv[2])
t = cfg.read_text()
body = "\n".join(l for l in colours.splitlines() if l.startswith("set $base"))
new = ("# >>> BEGIN generated theme colours >>>\n" + body +
       "\n# <<< END generated theme colours <<<")
t2 = re.sub(r"# >>> BEGIN generated theme colours >>>.*?# <<< END generated theme colours <<<",
            new, t, flags=re.S)
if t2 != t:
    cfg.write_text(t2)
INJECT
        echo "  ✓ $repo → spliced into ~/.config/i3/config"
        continue
    fi

    if [[ "$MODE" == "--check" ]]; then
        if [[ -f "$dest" ]] && cmp -s "$built" "$dest"; then
            echo "  ✓ $repo — up to date"
        else
            echo "  ✗ $repo — DRIFT: $dest differs from generated"; drift=1
        fi
    else
        mkdir -p "$(dirname "$dest")"
        cp -f "$built" "$dest"
        echo "  ✓ $repo → $dest"
    fi
done

# --- terminal: tinted-shell sets colours via OSC escapes -----------------
# This replaces the old imperative set_terminal_theme.sh (dconf writes):
# it works in ANY terminal that honours OSC sequences, including GNOME
# Terminal, with no per-terminal configuration and nothing to re-run on a
# new machine. Add to .bashrc:
#     source ~/.cache/tinted-templates/tinted-shell/scripts/base24-thrifted-rug.sh
if [[ "$MODE" != "--check" ]]; then
    dir="$CACHE/tinted-shell"
    [[ -d "$dir" ]] || git clone -q --depth 1 https://github.com/tinted-theming/tinted-shell.git "$dir" 2>/dev/null || true
    if [[ -d "$dir" ]]; then
        tinted-builder-rust build --schemes-dir "$SCHEMES_DIR" "$dir" >/dev/null 2>&1 || true
        sh="$dir/scripts/base24-$THEME.sh"
        [[ -f "$sh" ]] && { echo "  ✓ tinted-shell → $sh"; }
    fi
fi

echo
if [[ "$MODE" == "--check" ]]; then
    [[ $drift -eq 0 ]] && echo "✅ no drift" || { echo "❌ drift detected — run ./apply-theme.sh"; exit 1; }
else
    echo "✅ theme applied. Reload i3 (\$mod+Shift+R) / restart polybar to see changes."
fi
