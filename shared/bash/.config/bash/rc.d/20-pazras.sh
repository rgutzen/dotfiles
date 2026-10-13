# PAZRAS — the P.A.Z.R.A.S folder system and its helper scripts.
# 06_SYSTEM is synced separately from this repo, so both lines are guarded:
# on a machine where it has not landed yet this is simply a no-op.

# PATH: not set here. `familiar` is a symlink in ~/.local/bin (already on PATH
# for every shell, login or not), created by `familiar structure link` and
# carried in this repo as shared/bin/.local/bin/familiar. Adding engine/ to PATH
# exposed every engine script as a command, which is not what was wanted.
[ -f "$HOME/06_SYSTEM/engine/host/pazras-aliases.sh" ] && . "$HOME/06_SYSTEM/engine/host/pazras-aliases.sh"
