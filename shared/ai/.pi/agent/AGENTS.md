# Output discipline: prefer rtk for bulk readout

Prefer the `rtk` wrapper over the raw tool:

- bulk reads:  `rtk read`/`rtk rg`/`rtk grep`/`rtk ls`/`rtk find`/`rtk tree`
- bulk git:    `rtk git <subcommand>` (status, diff, log, …)
- anything in `rtk -h`'s command list with a bigger output
- quick shape/size: `rtk ls --help`, `rtk smart` for a 2-line summary

This is a *preference*, not a rule: keep the native tool when you need exact,
unfiltered bytes or when the output is already short. 
A `tool_call` hook (see the `rtk` Pi extension, if loaded) already rewrites
bash commands to their `rtk` form automatically; this note is for the rounds
you choose the tool yourself, especially when listing or searching a tree.


# When another agent — or the user — addresses you by name

A pane session in herdr can be named and driven from elsewhere:
`herdr agent prompt <name> "…" --wait` sends you work, `herdr agent read <name>`
prints your output, and your own pane is `$HERDR_PANE_ID`.

If a prompt assumes you know what the user is looking at, look instead of
guessing: `herdr pane current` names the focused pane, `herdr pane read
<pane_id>` prints its visible screen (text only, as currently rendered — a
cursor or a selection is not part of it). Nothing else crosses a pane boundary;
a handoff is a prompt. Read the path you were given before inferring intent, and
say plainly what you could not see.
