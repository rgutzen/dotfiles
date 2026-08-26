# ~/.profile — login environment. POSIX sh only, no bashisms.
#
# Environment for every login session, bash or not: PATH and tool env scripts.
# No aliases, no prompt, no completion — those are interactive and live in
# ~/.config/bash/rc.d/. Sourced explicitly from .bash_profile; bash itself reads
# that file instead of this one.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

[ -d "$HOME/bin" ]        && PATH="$HOME/bin:$PATH"
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/.elan/bin" ]  && PATH="$HOME/.elan/bin:$PATH"
export PATH

# Toolchain env scripts, each guarded — neither is on every machine.
# (.local/bin/env is what Omarchy wrote as ".local/share/../bin/env".)
[ -f "$HOME/.cargo/env" ]     && . "$HOME/.cargo/env"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
