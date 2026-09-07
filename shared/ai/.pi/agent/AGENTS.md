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

