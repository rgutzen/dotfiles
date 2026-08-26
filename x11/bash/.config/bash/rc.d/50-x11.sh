# X11 session only — stowed when XDG_SESSION_TYPE is not wayland.

# CapsLock → Escape. setxkbmap is an X client; under Wayland it does nothing
# (Hyprland sets this in its own config instead).
command -v setxkbmap >/dev/null && setxkbmap -option caps:escape

# Screen lock — i3-specific, so it lives here rather than in .bash_aliases.
# (Was dropped from the shared aliases during the Omarchy cleanup, where it is
# meaningless; delete this line if you don't want it back on the X280 either.)
alias lock='i3lock -c 000000'
