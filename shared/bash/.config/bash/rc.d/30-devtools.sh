# Language toolchains. Every block is guarded — no machine has all of them, and
# an unguarded init here is an error on every interactive shell.
#
# NOTE: `conda init` rewrites its managed block in ~/.bashrc, which is now a
# spine. If you ever run it, move the block it adds back into this file.

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if [ -x "$HOME/miniforge3/bin/conda" ]; then
    __conda_setup="$("$HOME/miniforge3/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    elif [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniforge3/etc/profile.d/conda.sh"
    else
        PATH="$HOME/miniforge3/bin:$PATH"
    fi
    unset __conda_setup
fi
[ -f "$HOME/miniforge3/etc/profile.d/mamba.sh" ] && . "$HOME/miniforge3/etc/profile.d/mamba.sh"
# <<< conda initialize <<<

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ]         && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && PATH="$BUN_INSTALL/bin:$PATH"
[ -d "$HOME/go/bin" ]     && PATH="$HOME/go/bin:$PATH"
export PATH
