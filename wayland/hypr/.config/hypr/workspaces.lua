-- Shared workspaces: each workspace exists once and belongs to whichever
-- monitor is showing it, as Omarchy did before 4.5.
--
-- 4.5's default/hypr/monitor-workspaces.lua gives every monitor a block of ten
-- of its own (1-10 on the laptop panel, 11-20 on the next) and renumbers
-- workspaces into a block on every monitor change. It has no off switch, and it
-- is the only thing defining o.workspaces, which default/hypr/bindings/tiling.lua
-- calls while it loads. So this file claims its module slot in package.loaded
-- before default/hypr/omarchy.lua requires it: Hyprland's require is Lua's, and
-- a filled slot means the module body never runs, so none of its handlers (start,
-- monitor add/remove, config reload) are registered and it cannot renumber
-- anything. What is left is the same API, spelled with Hyprland's own
-- dispatchers, loaded from hyprland.lua ahead of the defaults.
--
-- Measured 2026-11: with the slot filled the real module does not execute
-- (marker file written by the module never appeared) and hyprctl configerrors
-- stays clean.

-- Loaded ahead of the defaults, so the helper table has to be here already;
-- helpers.lua creates it once and every later require gets the same one.
require("default.hypr.helpers")

-- A bind that is a function shows in the keybindings menu through the Lua
-- expression it stands for, as Omarchy's own helper does.
local function expression(fn, text)
  o.bind_expressions[fn] = text
  return fn
end

local workspaces = { slots = 10 }

-- Super + 3: the one workspace 3, wherever it is on screen.
--
-- A bar names its own monitor, because a click on the third number of a monitor's
-- row means "show 3 here", not "follow 3 over there". Focusing a workspace that
-- is already up on the other monitor moves the focus instead, so the workspace
-- has to be moved to the named monitor first. A slot with no workspace yet is
-- created there by focusing the monitor, then the number.
function workspaces.focus(slot, monitor_name)
  return expression(function()
    local monitor = monitor_name and hl.get_monitor(monitor_name) or nil
    if not monitor then
      hl.dispatch(hl.dsp.focus({ workspace = tostring(slot) }))
      return
    end

    local workspace = hl.get_workspace(slot)

    -- Moving a workspace to a monitor leaves the monitor showing what it showed,
    -- so the number is focused afterwards, on the monitor it now belongs to.
    if workspace and workspace.monitor and workspace.monitor.name ~= monitor.name then
      hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(slot), monitor = monitor.name }))
    end

    hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
    hl.dispatch(hl.dsp.focus({ workspace = tostring(slot) }))
  end, "o.workspaces.focus(" .. slot .. (monitor_name and ", " .. string.format("%q", monitor_name) or "") .. ")")
end

-- Super + Shift + 3, and Super + Shift + Alt + 3 for moving without following.
function workspaces.move_window(slot, follow)
  return hl.dsp.window.move({ workspace = tostring(slot), follow = follow ~= false })
end

-- The workspace or window goes to the monitor in that direction, as the native
-- dispatchers take it. Hyprland reports a move toward no monitor as an error on
-- screen, so a direction with nothing in it does nothing.
local function toward(direction, target, text)
  return expression(function()
    local monitor = hl.get_monitor(direction)
    if monitor then
      hl.dispatch(target(monitor))
    end
  end, text)
end

function workspaces.move_to_monitor(direction)
  return toward(direction, function(monitor)
    return hl.dsp.workspace.move({ monitor = monitor.name })
  end, "o.workspaces.move_to_monitor(" .. string.format("%q", direction) .. ")")
end

function workspaces.move_window_to_monitor(direction)
  return toward(direction, function(monitor)
    return hl.dsp.window.move({ monitor = monitor.name })
  end, "o.workspaces.move_window_to_monitor(" .. string.format("%q", direction) .. ")")
end

-- A slot is its own workspace number now.
function workspaces.workspace_id(_, slot)
  return slot
end

o.workspaces = workspaces

package.loaded["default.hypr.monitor-workspaces"] = workspaces

return workspaces
