# Thrifted Rug — theming

A warm, earthy dark theme, aligned with the [tinted-theming](https://github.com/tinted-theming)
**base24** standard so it can drive the existing ecosystem of ~40 application templates
instead of hand-maintained per-app colour files.

## Layout

```
theme/
├── schemes/
│   ├── base24/thrifted-rug.yaml   ← SOURCE OF TRUTH (24 slots)
│   └── base16/thrifted-rug.yaml   ← GENERATED subset (base00–base0F)
├── palette-extended.env           ← deep shades base24 has no slot for
├── tinty/config.toml              ← tinty config (terminal / interactive use)
├── apply-theme.sh                 ← build + install driver
└── README.md
```

## Why two scheme files

`base24` = `base16` + 8 slots (2 darker backgrounds + 6 bright ANSI variants).
This palette is **5 accent families × 3 shades** (deep / primary / light), which
maps onto base24 almost exactly:

| Family shade | base24 role |
|---|---|
| **primary** (e.g. `#8fb573` sage) | normal ANSI — `base08`–`base0F` |
| **light** (e.g. `#a8c498`) | **bright ANSI** — `base12`–`base17` |
| **deep** (e.g. `#5c7c58`) | *no slot* → `palette-extended.env` |

Most community templates (`base16-i3`, `base16-polybar`, `base16-waybar`, …)
are **base16-only**, so `apply-theme.sh` regenerates a base16 subset from the
base24 source on every run. One source of truth, two published forms.

## Usage

```bash
./apply-theme.sh            # build + install for the current session (x11/wayland)
./apply-theme.sh --check    # verify installed files match generated — no writes
./apply-theme.sh --sync     # git pull cached template repos first
```

Session-aware: polybar/i3/rofi on X11, waybar on Wayland, gtk/dunst on both.

## Terminal

`tinted-shell` sets colours via **OSC escape sequences**, so it works in any
compliant terminal — including GNOME Terminal — with no per-terminal setup.
This replaces the old imperative `set_terminal_theme.sh` (which wrote dconf
keys tied to one specific GNOME Terminal profile UUID and would not survive
the move to Omarchy).

Add to `.bashrc`:
```bash
source ~/.cache/tinted-templates/tinted-shell/scripts/base24-thrifted-rug.sh
```

## Adding an application

1. Find a template at <https://github.com/tinted-theming> (or any base16/base24 template repo)
2. Add a line to `TEMPLATES` in `apply-theme.sh`:
   `"repo-name|built-output-glob|$HOME/destination/path|all|x11|wayland"`
3. Run `./apply-theme.sh`

## Changing a colour

Edit **`schemes/base24/thrifted-rug.yaml` only**, then `./apply-theme.sh`.
The base16 subset and every application config regenerate from it.

Commit the generated files: `git diff` then shows exactly what a palette change
did across every application at once, and `--check` catches drift.

## Known gaps

- **VS Code** — `tinted-vscode` builds an extension rather than a colour file;
  needs separate packaging. `workbench.colorCustomizations` in `settings.json`
  remains a stopgap.
- **Firefox** — `userChrome.css` has no upstream template; still hand-maintained.
- **Deep accent shades** are unavailable to upstream templates by construction
  (no base24 slot). Only custom templates can use `palette-extended.env`.

## Omarchy

Omarchy ships its own theming system. Add an Omarchy-format template to the
manifest so `thrifted-rug` becomes a first-class Omarchy theme rather than
something that fights the distro on each update.

## Provenance

Replaces `02_AREAS/B_Tech/config_files/color_themes/thrifted-rug/`, where the
palette lived in a README as prose and `#1a1614` was duplicated **22 times
across 6 files**. Colours are unchanged; five were derived to fill base24 slots
the original palette lacked (`base06`, `base07`, `base10`, `base11`, `base12`).
