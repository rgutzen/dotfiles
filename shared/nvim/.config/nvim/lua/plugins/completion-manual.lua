-- The completion menu no longer opens on its own: while it is open, <Up>/<Down>
-- move through its items instead of the buffer. Open it with <C-Space>.
return {
	{
		"saghen/blink.cmp",
		opts = {
			completion = {
				menu = { auto_show = false },
				ghost_text = { enabled = false },
			},
		},
	},
}
