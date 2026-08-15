#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar
if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload -c $HOME/.config/polybar/thrifted-rug-config thrifted-rug  &
  done
else
  polybar --reload -c $HOME/.config/polybar/thrifted-rug-config thrifted-rug  &
fi

# polybar -c $HOME/.config/polybar/dark-config nord-down 

echo "Bars launched..."
