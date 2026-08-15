# dotfiles

Configuration for a P.A.Z.R.A.S workflow, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Currently spans **X280** (Ubuntu 22.04 · i3 · X11) and **Omarchy** (Arch · Hyprland · Wayland).

## Quick start

```bash
git clone https://github.com/rgutzen/dotfiles ~/02_AREAS/B_Tech/dotfiles
cd ~/02_AREAS/B_Tech/dotfiles
./bootstrap.sh
```

Then fill in `~/.config/bash/local.sh` and `~/.config/git/local` from your password manager.

## Layout

```
shared/     portable across every machine
  bash/     .bashrc .bash_aliases .profile
  git/      .gitconfig .config/git/
  conda/    .condarc
  gtk/      .config/gtk-{2,3,4}.0/
  theme/    base24 colour scheme + generator  (see theme/README.md)

x11/        X280 — Ubuntu, i3, X11
  i3/       polybar/       autorandr/

wayland/    Omarchy — Hyprland (populate on the new machine)
  hypr/     waybar/

secrets.example/   templates — names only, never values
```

**Directories, not branches.** Machines are *parallel variants that coexist*, not
divergent history. With directories, a change to shared `.bashrc` is one edit that
both machines get; with branches it would be a permanent merge obligation, and you
could never see the i3 and Hyprland configs side by side while porting between them.

## How it works

Stow symlinks each package's contents into `$HOME`, mirroring the internal path:

```
shared/bash/.bashrc          →  ~/.bashrc
x11/i3/.config/i3/config     →  ~/.config/i3/config
```

**The real file lives in the repo; `$HOME` holds a symlink.** So editing `~/.bashrc`
*is* editing the repo — `git status` shows config drift with nothing to remember and
no sync step to forget.

`bootstrap.sh` picks packages from `$XDG_SESSION_TYPE`, so one command works on both
machines. It skips packages that are still empty placeholders.

## Machine-local values and secrets

This repo is **public**. Anything machine-specific or secret goes in untracked files
that the tracked configs `include`:

| Tracked (public) | Untracked (local) |
|---|---|
| `shared/bash/.bashrc` | `~/.config/bash/local.sh` |
| `shared/git/.gitconfig` | `~/.config/git/local` |

Templates with dummy values live in `secrets.example/`. Secrets therefore have a
designated home *outside* git — leaking one requires actively putting it in the
wrong place, rather than merely forgetting.

`.gitignore` is a **deny-list** for the same reason.

## Theming

A single base24 colour scheme generates the colours for i3, polybar, waybar, rofi,
dunst, GTK and the terminal. Change a colour in one file, run one script.

```bash
./shared/theme/apply-theme.sh            # build + install
./shared/theme/apply-theme.sh --check    # verify no drift
```

See [`shared/theme/README.md`](shared/theme/README.md).

## Notes

- **i3 4.20.1 has no `include` directive** (added in 4.21), so generated colours are
  spliced into `~/.config/i3/config` between markers by `apply-theme.sh`.
- i3 config was migrated from the legacy `~/.i3/config` to XDG `~/.config/i3/config`.
- `wayland/` is intentionally empty until Omarchy is installed — live with its
  defaults for a couple of weeks before porting i3 habits.
