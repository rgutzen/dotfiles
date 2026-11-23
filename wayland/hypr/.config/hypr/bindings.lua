-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding. o.rebind takes the same arguments as o.bind.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- o.rebind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { panel = "omarchy.emojis" })
--
o.rebind("SUPER + SHIFT + E", "Thunderbird", "thunderbird")
hl.unbind("SUPER + SHIFT + ALT + E")

-- herdr: one session per context, each with its own accent (herdr-session).
o.bind("SUPER + ALT + P", "herdr personal", "xdg-terminal-exec herdr-session personal")
o.bind("SUPER + ALT + W", "herdr work", "xdg-terminal-exec herdr-session work")

-- voxtype: one hotkey; herdr-voice turns a leading "herdr <verb>" into a command.
-- voice-record stops any speech first, so the microphone hears the room.
o.bind("SUPER + SHIFT + L", "Dictate", "voice-record")

-- speech out: speak the selection, same key stops playback (voice-out V2).
o.rebind("SUPER + ALT + L", "Speak selection", "speak-selection")
-- One-chord twin of Omarchy's ALT + SPACE (toggle dictation): speech in on
-- ALT + SPACE, speech out on CTRL + ALT + SPACE. Never on right Alt: Omarchy
-- binds ALT + Alt_R as push-to-talk with ignore_mods, so any right-Alt press
-- starts a recording, and `say` stays silent while one records (2026-11-23).
o.bind("CTRL + ALT + SPACE", "Speak selection", "speak-selection")
-- speech out: freeze where it is, press again to continue.
o.bind("SUPER + ALT + M", "Pause speech", "say --toggle-pause")
-- speech out: one global mute; stops every lane, chat replies stay silent until pressed again (voice-out C5).
o.bind("SUPER + ALT + J", "Mute speech", "voice-mute")
