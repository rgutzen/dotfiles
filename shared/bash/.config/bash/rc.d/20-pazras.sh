# PAZRAS — the P.A.Z.R.A.S folder system and its helper scripts.
# 06_SYSTEM is synced separately from this repo, so both lines are guarded:
# on a machine where it has not landed yet this is simply a no-op.

# PATH: not set here. `familiar` is a symlink in ~/.local/bin (already on PATH
# for every shell, login or not), created by `familiar structure link` and
# carried in this repo as shared/bin/.local/bin/familiar. Adding engine/ to PATH
# exposed every engine script as a command, which is not what was wanted.
# The territory hops (structure's) and the shell's notices (interface's), since
# 06_SYSTEM's dev/ontology K2i split the old aliases file in two.
[ -f "$HOME/06_SYSTEM/engine/structure/pazras-aliases.sh" ] && . "$HOME/06_SYSTEM/engine/structure/pazras-aliases.sh"
[ -f "$HOME/06_SYSTEM/engine/interface/notices.sh" ] && . "$HOME/06_SYSTEM/engine/interface/notices.sh"
