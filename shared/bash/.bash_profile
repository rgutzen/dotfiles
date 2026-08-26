# ~/.bash_profile — login shells.
#
# Bash reads only the FIRST of ~/.bash_profile, ~/.bash_login, ~/.profile for a
# login shell. Omarchy ships its own .bash_profile, so on that machine ~/.profile
# was never read at all — not overridden, never read. That silent shadowing is
# part of how the two machines drifted apart.
#
# This file exists to make the chain explicit and identical everywhere:
#
#   login shell        .bash_profile → .profile (env) → .bashrc (interactive)
#   interactive only                                  → .bashrc
#
# So nothing belongs in here. Environment goes in .profile, interactive
# configuration goes in a ~/.config/bash/rc.d/ fragment.

[ -f ~/.profile ] && . ~/.profile
[ -f ~/.bashrc ]  && . ~/.bashrc
