-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Omarchy's monitor-scaling tool rewrites omarchy_gdk_scale/omarchy_monitor_scale
-- when scaling the focused monitor; keep them as the internal's scale.
local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))

-- Internal laptop panel: bottom (0,0), scale 1.6 → 2880x1800 px = 1800x1125 logical.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })

-- External BenQ GW2780: above the internal, horizontally centered, scale 1.
-- 1920x1080 px @1.0 = 1920x1080 logical; centered over 1800-wide panel → x = (1800-1920)/2 = -60;
-- bottom edge meets internal's top → y = -1080.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "-60x-1080", scale = 1 })

-- Catch-all for any other monitor, e.g. a USB-C dock output.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
