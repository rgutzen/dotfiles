# PAZRAS — the PARA folder system and its helper scripts.
# 06_SYSTEM is synced separately from this repo, so both lines are guarded:
# on a machine where it has not landed yet this is simply a no-op.

[ -d "$HOME/06_SYSTEM/scripts" ] && PATH="$PATH:$HOME/06_SYSTEM/scripts" && export PATH
[ -f "$HOME/06_SYSTEM/scripts/para-aliases.sh" ] && . "$HOME/06_SYSTEM/scripts/para-aliases.sh"
