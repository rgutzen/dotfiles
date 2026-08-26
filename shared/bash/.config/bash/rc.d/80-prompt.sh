# Prompt. starship overwrites PS1 entirely, which is why no PS1 is set anywhere
# else in this repo — see the note in 10-shell.sh.
command -v starship >/dev/null && eval "$(starship init bash)"
