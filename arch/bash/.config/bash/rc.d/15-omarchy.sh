# Omarchy's own aliases and functions — stowed when /etc/arch-release exists.
#
# Sourced, not vendored: Omarchy's updater owns this file, so a tracked copy
# would be a fork needing manual resync. Anything you want to override goes in a
# later fragment or in ~/.config/bash/local.sh, both of which run after this.
#
# Guarded on OMARCHY_PATH being set, which matters: unguarded,
# `source "$OMARCHY_PATH/default/bash/rc"` expands to "/default/bash/rc" on any
# machine without Omarchy and errors on every single shell. The tier already
# keeps this file off non-Arch machines; the guard also covers an Arch box where
# Omarchy itself is absent or its env-bootstrap has moved.
[ -n "$OMARCHY_PATH" ] && [ -r "$OMARCHY_PATH/default/bash/rc" ] \
    && . "$OMARCHY_PATH/default/bash/rc"
