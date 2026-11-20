# rtk

For bulk output, prefer `rtk` (`rtk read|grep|find|ls|tree`, `rtk git …`; list: `rtk -h`). A hook already rewrites bash commands; use the raw tool when you need exact bytes.

# herdr

You may be driven from another pane: `herdr agent prompt <name> "…" --wait`, `herdr agent read <name>`; yours is `$HERDR_PANE_ID`. To see what the user sees: `herdr pane current`, then `herdr pane read <id>` (rendered text only, no cursor or selection). A handoff is only its prompt: read the paths given, and say what you could not see.
