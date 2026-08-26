# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

[[ -f ~/.bashrc ]] && . ~/.bashrc

. "$HOME/.local/share/../bin/env"

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

export PATH="$PATH:$HOME/06_SYSTEM/scripts/"


if [ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ]; then
    . "$HOME/miniforge3/etc/profile.d/mamba.sh"
fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export OPENCODE_DISABLE_EXTERNAL_SKILLS=1

# OpenClaw Completion
[ -f "$HOME/.openclaw/completions/openclaw.bash" ] \
    && . "$HOME/.openclaw/completions/openclaw.bash"

# >>> oh-my-opencode-slim background subagents >>>
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true
# <<< oh-my-opencode-slim background subagents <<<

# Omarchy ships its own bash defaults and its updater owns them. Source them
# if present rather than forking a copy into this repo; the guard makes this a
# no-op everywhere else. Placed before the local overrides so ours win.
[ -f ~/.local/share/omarchy/default/bash/rc ] && . ~/.local/share/omarchy/default/bash/rc

# machine-local overrides & secrets (untracked; see dotfiles/secrets.example/)
[ -f ~/.config/bash/local.sh ] && . ~/.config/bash/local.sh
