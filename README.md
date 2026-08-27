# dotfiles

Configuration for a P.A.Z.R.A.S workflow, managed with [GNU Stow](https://www.gnu.org/software/stow/).
Currently spans **X280** (Ubuntu 22.04 · i3 · X11) and **Omarchy** (Arch · Hyprland · Wayland).

## Deploying

`bootstrap.sh` is idempotent — re-run it any time. Which path you take depends on
whether the machine already has configs of its own.

### On a fresh machine

```bash
sudo pacman -S stow          # Arch/Omarchy   (Debian/Ubuntu: sudo apt install stow)
git clone git@github.com:rgutzen/dotfiles ~/02_AREAS/B_Tech/dotfiles
cd ~/02_AREAS/B_Tech/dotfiles

./bootstrap.sh --dry-run     # 1. see what would be linked, change nothing
./bootstrap.sh               # 2. link it
```

Then, in order:

1. **Fill in the local overrides.** `bootstrap.sh` seeds `~/.config/bash/local.sh`
   and `~/.config/git/local` from `secrets.example/`; the values come from Proton
   Pass. Nothing else in this repo is machine-specific.
2. **Install the theme builder** if it warned about one:
   `cargo install tinted-builder-rust --locked && ./shared/theme/apply-theme.sh`
3. **Set up the AI harnesses** — see [`shared/ai/README.md`](shared/ai/README.md).
   Plugins reinstall themselves from the manifest; the accounts need fresh logins.
4. **Open a new shell.** `.bashrc` is only read at shell start, so the previous
   shell still has the old environment.

### On a machine that already has configs

A fresh OS install ships its own `~/.bashrc`, and Claude Code or OpenCode will have
written their own configs on first run. Stow refuses to overwrite a real file, so a
plain `./bootstrap.sh` aborts with `WARNING! stowing <pkg> would cause conflicts`.

`--adopt` resolves that by **inverting** the conflict: the file already on the
machine is moved *into* the package and symlinked back, so it lands as an unstaged
diff and git becomes the merge UI.

```bash
git status                   # 1. must be clean — --adopt refuses otherwise
./bootstrap.sh --dry-run     # 2. see which files will collide
./bootstrap.sh --adopt       # 3. adopt them; stops before the theme/timer steps

git diff                     # 4. everything above is what THIS MACHINE had
```

Then resolve each file, in whatever mix the diff calls for:

| Intent | Command |
|---|---|
| Keep this repo's version | `git checkout -- <file>` |
| Keep the new machine's version | leave it — then commit it |
| Merge the two | `git checkout -p <file>` |

```bash
./bootstrap.sh               # 5. re-run for the theme and timer steps
git commit                   # 6. commit whatever you chose to keep
```

Step 3 deliberately stops early: resolving the diff before applying the theme and
enabling timers keeps one decision on screen at a time.

**`.bashrc` is the one that usually wants a real merge**, not a keep-or-discard.
Omarchy's version sources its own defaults, so take *that* hunk and discard the
rest — or better, keep this repo's file, since it already sources Omarchy's
defaults behind a guard (see "Distro defaults are sourced, not vendored" below).

### Other modes

```bash
./bootstrap.sh --delete      # unstow everything; $HOME keeps no links
```

Removing a file from a package does not remove its link — `./bootstrap.sh` uses
`--restow` (unstow, then stow), which clears links whose source is gone.

## Layout

```
shared/     portable across every machine
  bash/     .bash_profile .profile .bashrc + .config/bash/rc.d/  (see below)
  git/      .gitconfig .config/git/
  conda/    .condarc
  gtk/      .config/gtk-{2,3,4}.0/
  theme/    base24 colour scheme + generator  (see theme/README.md)
  ai/       Claude Code + OpenCode config, curated plugin/skill set  (see ai/README.md)

x11/        session tier — i3, X11
  i3/       polybar/  autorandr/  wm-scripts/

wayland/    session tier — Hyprland (populate on the new machine)
  hypr/     waybar/

ubuntu/     OS tier — apt/snap maintenance scripts, Debian shell bits
arch/       OS tier — Omarchy shell bits (add os-scripts when needed)

secrets.example/   templates — names only, never values
```

**Session tier and OS tier are separate axes.** `x11/`|`wayland/` is selected by
`$XDG_SESSION_TYPE`; `ubuntu/`|`arch/` by `/etc/debian_version` or
`/etc/arch-release`. Omarchy happens to be Arch *and* Wayland, but its pacman
scripts apply in a bare TTY and Hyprland-on-Ubuntu would want the wayland tier
with none of them. Collapsing the two would make each machine a special case
instead of a point in a two-axis grid.

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

`bootstrap.sh` picks packages per tier, so one command works on every machine. It
skips packages that are still empty placeholders.

### Directories are never folded

Stow's default is *tree folding*: if `~/.config/foo` doesn't exist, it links the
whole directory in one go and `~/.config/foo` becomes a symlink into this repo.
Anything the **application** then writes into that directory lands inside git —
which is exactly how `gtk-3.0/bookmarks` and `servers` ended up committed to this
public repo (since removed), and how a fresh machine would end up with systemd's
`timers.target.wants/` symlinks committed. So `bootstrap.sh` passes `--no-folding` everywhere. The cost
is that a newly added file needs a re-run to appear in `$HOME`; the script is
idempotent, so just re-run it.

### Why `--adopt` instead of a keep/overwrite prompt

The procedure is under [Deploying](#on-a-machine-that-already-has-configs); this is
why it works that way. A per-file "keep or overwrite?" prompt is the obvious
alternative and is worse on both counts:

- **At the moment it fires you cannot see what differs.** `--adopt` turns the
  conflict into a diff you read at leisure, with the whole set in front of you.
- **The honest answer is often "merge".** Omarchy's `.bashrc` is not junk to
  discard, nor a replacement for this one — you want a few hunks out of it. A
  binary prompt cannot express that; `git checkout -p` can.

The clean-tree check is the entire safety mechanism. `--adopt` really does
overwrite the repo's copy, and without a clean tree adopted content is
indistinguishable from your own uncommitted edits.

### Bash is composed from fragments, not copied per machine

`~/.bashrc` is a **spine**: it sources numbered fragments out of two drop-in
directories and does nothing else.

```
env.d/*.sh   environment — every shell, interactive or not
rc.d/*.sh    interactive only — aliases, prompt, completion, colours
```

Stow assembles those directories from whichever packages apply to the machine.
On the X280 that is three packages landing in one directory:

```
shared/bash  →  10-shell  20-pazras  30-devtools  40-ai  80-prompt  90-theme
ubuntu/bash  →      15-ubuntu          (snap, linuxbrew, texlive, lesspipe)
x11/bash     →                    50-x11        (setxkbmap, i3 lock alias)
```

On Omarchy, `arch/bash` supplies `15-omarchy` in both `env.d/` and `rc.d/`
instead, and `50-x11` is simply absent. **A shared change is still one edit**,
which is the whole reason this repo uses directories rather than branches.

Three properties make it work:

- **Numeric prefixes** give a deterministic order across packages, since no
  package knows what the others contribute. `15-ubuntu` slots between `10-shell`
  and `20-pazras` regardless of which package delivered it.
- **No file is written by two packages**, so stow merges them instead of
  reporting a conflict. This needs `--no-folding`: with tree folding the first
  package would claim `rc.d/` as one directory symlink and the next would collide.
- **An unmatched glob stays literal** and fails the `-r` test, so a missing
  drop-in directory is a no-op. `env.d/` does not exist on the X280 at all.

What is deliberately *not* tracked is the distro skeleton — `debian_chroot`,
`lesspipe`, and the ~35-line `PS1` block each distro ships in `/etc/skel/.bashrc`.
That block was dead on both machines anyway, because starship replaces `PS1`
wholesale; carrying it only created divergence to maintain.

### Login shells: `.bash_profile` is the entry point

Bash reads only the **first** of `~/.bash_profile`, `~/.bash_login`, `~/.profile`
for a login shell. Omarchy ships its own `.bash_profile`, so this repo's
`.profile` was never read there — not overridden, never read. That silent
shadowing is a large part of how the two machines drifted apart.

`shared/bash/.bash_profile` now makes the chain explicit and identical everywhere:

```
login shell        .bash_profile → .profile (env) → .bashrc (interactive)
interactive only                                  → .bashrc
```

So `.bash_profile` holds nothing of its own. Environment goes in `.profile`;
interactive configuration goes in an `rc.d/` fragment. Putting interactive
config directly in `.bash_profile` — as the Omarchy version did — means a new
terminal window and a login shell get different environments.

### Distro defaults are sourced, not vendored

Omarchy ships shell defaults its own updater owns. Copying them into a tier
here would create a fork you'd have to hand-resync, so `arch/bash`'s fragments
source them behind a guard instead:

```bash
# env.d/15-omarchy.sh — needed by non-interactive shells too
[ -r /usr/share/omarchy/default/bash/env-bootstrap ] && . /usr/share/omarchy/default/bash/env-bootstrap
# rc.d/15-omarchy.sh
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/rc" ] && . "$OMARCHY_PATH/default/bash/rc"
```

The `-n "$OMARCHY_PATH"` test is load-bearing. Unguarded,
`source "$OMARCHY_PATH/default/bash/rc"` expands to `/default/bash/rc` wherever
Omarchy is absent and errors on *every shell*.

Same reasoning as the AI plugins: track the manifest, let upstream own the
payload. Every fragment is guarded the same way (`starship`, `nvm`, `cargo`,
`conda`, `setxkbmap`, `lesspipe`), so a machine with fewer tools installed gets
a quiet no-op rather than an error on every interactive shell.

## Machine-local values and secrets

This repo is **public**. Anything machine-specific or secret goes in untracked files
that the tracked configs `include`:

| Tracked (public) | Untracked (local) |
|---|---|
| `shared/bash/.bashrc` | `~/.config/bash/local.sh` |
| `shared/git/.gitconfig` | `~/.config/git/local` |
| — | `~/.config/gtk-3.0/{bookmarks,servers}` |

GTK's file-chooser bookmarks and network locations are deliberately **not** in any
package. They are machine-local by nature and they name home-directory layout,
internal hostnames and remote usernames — nothing that belongs in a public repo.
They live in `$HOME` and in backups; `.gitignore` denies them so a future folded
directory cannot quietly re-add them.

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

## AI tooling

Claude Code + OpenCode config, deliberately curated (not everything that's
ever been installed makes the cut — see the audit in the README below).

See [`shared/ai/README.md`](shared/ai/README.md).

## Notes

- **i3 4.20.1 has no `include` directive** (added in 4.21), so generated colours are
  spliced into `~/.config/i3/config` between markers by `apply-theme.sh`.
- i3 config was migrated from the legacy `~/.i3/config` to XDG `~/.config/i3/config`.
- `wayland/` is intentionally empty until Omarchy is installed — live with its
  defaults for a couple of weeks before porting i3 habits.
