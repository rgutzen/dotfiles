-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SslasslshIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")
--
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT +E", "Thunderbird", "thunderbird")
hl.unbind("SUPER + SHIFT + ALT + E")

-- herdr: one session per context, each with its own accent (herdr-session).
o.bind("SUPER + ALT + P", "herdr personal", "xdg-terminal-exec herdr-session personal")
o.bind("SUPER + ALT + W", "herdr work", "xdg-terminal-exec herdr-session work")

-- voxtype: one hotkey; herdr-voice turns a leading "herdr <verb>" into a command.
-- voice-record stops any speech first, so the microphone hears the room.
o.bind("SUPER + SHIFT + L", "Dictate", "voice-record")

-- speech out: speak the selection, same key stops playback (voice-out V2).
o.bind("SUPER + ALT + L", "Speak selection", "speak-selection")
