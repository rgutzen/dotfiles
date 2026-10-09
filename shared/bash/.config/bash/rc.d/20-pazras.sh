# PAZRAS — the P.A.Z.R.A.S folder system and its helper scripts.
# 06_SYSTEM is synced separately from this repo, so both lines are guarded:
# on a machine where it has not landed yet this is simply a no-op.

[ -d "$HOME/06_SYSTEM/engine" ] && PATH="$PATH:$HOME/06_SYSTEM/engine" && export PATH
[ -f "$HOME/06_SYSTEM/engine/host/pazras-aliases.sh" ] && . "$HOME/06_SYSTEM/engine/host/pazras-aliases.sh"
