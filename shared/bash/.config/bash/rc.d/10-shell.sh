# Shell basics: history, options, and the colour/ls aliases every machine wants.
#
# The distro skeletons' ~35-line PS1 block is deliberately not carried over —
# starship (80-prompt.sh) replaces PS1 wholesale, so it was dead code on both
# machines while still being a source of divergence between them.

HISTCONTROL=ignoreboth      # no duplicates, and no lines starting with a space
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend         # append to the history file, don't overwrite it
shopt -s checkwinsize       # keep LINES/COLUMNS right after each command

# colour support for ls/grep where dircolors exists
if command -v dircolors >/dev/null; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# notify when a long-running command finishes:  sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

[ -f ~/.bash_aliases ] && . ~/.bash_aliases

# programmable completion — the path differs by distro, so try both
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
