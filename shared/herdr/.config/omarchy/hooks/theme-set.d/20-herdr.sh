#!/usr/bin/env bash
# 20-herdr.sh — keep Herdr's UI palette in step with the active Omarchy theme.
#
# omarchy-theme-set runs every theme-set.d hook with the snake-cased theme name.
# Herdr has no config include, so config.toml is a generated view: the tracked
# config.toml.base followed by a [theme.custom] block derived from
# ~/.local/state/omarchy/current/theme/colors.toml. Same idea as apply-theme.sh,
# one application instead of twenty.
#
# Why not the community sync plugins (maxBRT/herdr-omarchy-theme-sync): they
# write [theme.custom] into config.toml, which is a tracked file here. A
# generated view keeps the repository free of runtime writes.

set -euo pipefail

theme=${1:-unknown}
colors=$HOME/.local/state/omarchy/current/theme/colors.toml
base=$HOME/.config/herdr/config.toml.base
out=$HOME/.config/herdr/config.toml

if [[ ! -r $colors || ! -r $base ]]; then
    echo "herdr-theme: need $colors and $base" >&2
    exit 0
fi

# First hex value of a top-level key; colors.toml is flat and quoted.
c() {
    sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"(#[0-9a-fA-F]{6})\".*/\1/p" "$colors" | head -n1
}

missing=0
for key in background darker_background dark_background lighter_background selection \
           muted dark_foreground foreground light_foreground accent \
           green yellow orange red cyan blue magenta; do
    [[ -n $(c "$key") ]] || { echo "herdr-theme: colors.toml has no $key" >&2; missing=1; }
done
(( missing == 0 )) || exit 1

tmp=$(mktemp "$out.XXXXXX")
{
    cat "$base"
    printf '\n# --- [theme.custom] generated from %s by 20-herdr.sh (%s) ---\n' \
        "$colors" "$theme"
    printf '[theme.custom]\n'
    printf '%-14s = "%s"\n' \
        panel_bg      "$(c background)" \
        sidebar_bg    "$(c darker_background)" \
        surface0      "$(c dark_background)" \
        surface1      "$(c lighter_background)" \
        surface_dim   "$(c dark_background)" \
        active_row_bg "$(c lighter_background)" \
        selection_bg  "$(c selection)" \
        overlay0      "$(c muted)" \
        overlay1      "$(c dark_foreground)" \
        text          "$(c foreground)" \
        subtext0      "$(c light_foreground)" \
        accent        "$(c accent)" \
        green         "$(c green)" \
        yellow        "$(c yellow)" \
        red           "$(c red)" \
        blue          "$(c blue)" \
        teal          "$(c cyan)" \
        mauve         "$(c magenta)" \
        peach         "$(c orange)"
} >"$tmp"

if ! HERDR_CONFIG_PATH=$tmp herdr config check >/dev/null; then
    echo "herdr-theme: generated config failed config check, keeping the old one" >&2
    HERDR_CONFIG_PATH=$tmp herdr config check 2>&1 | head -5 >&2 || true
    rm -f "$tmp"
    exit 1
fi

mv "$tmp" "$out"
herdr server reload-config >/dev/null 2>&1 || true
