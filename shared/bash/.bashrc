# ~/.bashrc — interactive shell configuration.
#
# This is a spine, not a config. The settings live in fragments under
# ~/.config/bash/, which stow assembles from several packages: shared/bash on
# every machine, plus ubuntu|arch and x11|wayland depending on where you are.
# Supporting a new machine means adding a fragment, never editing this file.
#
#   env.d/*.sh   environment — sourced for EVERY shell, interactive or not
#   rc.d/*.sh    interactive only — aliases, prompt, completion, colours
#
# Numeric prefixes make the order deterministic across packages, since no
# package knows what the others contribute:
#
#   10 shell basics · 15 distro · 20 PARA · 30 dev tools
#   40 AI · 50 session · 80 prompt · 90 theme
#
# An unmatched glob stays literal and fails the -r test, so a missing or empty
# drop-in directory is a no-op rather than an error.

# Environment first, deliberately above the interactive guard: Omarchy's
# env-bootstrap sets OMARCHY_PATH and PATH, and non-interactive shells need it
# too (`ssh omarchy some-omarchy-command`).
for _f in ~/.config/bash/env.d/*.sh; do [ -r "$_f" ] && . "$_f"; done
unset _f

# If not running interactively, stop here.
[[ $- != *i* ]] && return

for _f in ~/.config/bash/rc.d/*.sh; do [ -r "$_f" ] && . "$_f"; done
unset _f

# Machine-local overrides & secrets — last, so they win over every fragment.
# Untracked; see dotfiles/secrets.example/.
[ -f ~/.config/bash/local.sh ] && . ~/.config/bash/local.sh
