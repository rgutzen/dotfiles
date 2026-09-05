# Output discipline: prefer rtk for bulk readout

`rtk` (on PATH) is a token-optimising command proxy. For any command whose
output is large or line-heavy — directory listings, recursive finds, file
dumps for inspection, ripgrep hits, git status/log/diff, server/log tails —
prefer the `rtk` wrapper over the raw tool so its compact, deduplicated output
reaches context instead of the verbose native one:

- bulk reads:  `rtk read`/`rtk rg`/`rtk grep`/`rtk ls`/`rtk find`/`rtk tree`
- bulk git:    `rtk git <subcommand>` (status, diff, log, …)
- anything in `rtk -h`'s command list with a bigger output
- quick shape/size: `rtk ls --help`, `rtk smart` for a 2-line summary

This is a *preference*, not a rule: keep the native tool when you need exact,
unfiltered bytes or when the output is already short. `rtk` never hides or
alters content, it only condenses — so for `diff`/`read`/`grep` you still get
the facts you need. If `rtk` is unavailable for a case, fall back to the native
tool without comment.

A `tool_call` hook (see the `rtk` Pi extension, if loaded) already rewrites
bash commands to their `rtk` form automatically; this note is for the rounds
you choose the tool yourself, especially when listing or searching a tree.

<!-- BEGIN GENERATED always-on — 06_SYSTEM/agents/ -->
# Canonical Knowledge Base

The canonical, private, cross-harness agent knowledge base lives at
`~/06_SYSTEM/agents/`. Load its entry point before doing work:

`~/06_SYSTEM/agents/CONTEXT.md`
<!-- END GENERATED always-on -->
