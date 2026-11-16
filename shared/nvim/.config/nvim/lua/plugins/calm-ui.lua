-- Calmer reading surface: muted gruvbox, quiet markdown headings, and markdown
-- that stays rendered while moving and selecting. Omarchy owns which
-- colorscheme loads (plugins/theme.lua); the gruvbox spec below only takes
-- effect while the Omarchy theme is gruvbox.
return {
	{
		"ellisonleao/gruvbox.nvim",
		opts = {
			contrast = "soft",
			italic = { strings = false, emphasis = true, comments = true, operators = false, folds = false },
			-- Reverse video turns search hits into solid colour blocks.
			inverse = false,
			-- gruvbox-material's desaturated foregrounds in place of gruvbox's bright_*.
			palette_overrides = {
				light1 = "#d4be98",
				bright_red = "#ea6962",
				bright_green = "#a9b665",
				bright_yellow = "#d8a657",
				bright_blue = "#7daea3",
				bright_purple = "#d3869b",
				bright_aqua = "#89b482",
				bright_orange = "#e78a4e",
			},
			overrides = {
				Search = { bg = "#504945" },
				IncSearch = { bg = "#665c54", bold = true },
				CurSearch = { link = "IncSearch" },
			},
		},
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {
			-- Rendered in every mode except insert and replace, where the whole buffer
			-- is raw markdown. Modes match vim.fn.mode(true) exactly, hence the list;
			-- the default (n, c, t) dropped to raw markdown on `v`.
			render_modes = {
				"n", "no", "nov", "noV", "no\22", "niI", "niR", "niV", "nt", "ntT",
				"v", "vs", "V", "Vs", "\22", "\22s",
				"s", "S", "\19",
				"c", "cr", "cv", "cvr", "r", "rm", "r?", "!", "t",
			},
			-- Rendered modes never show the cursor line raw, so moving and selecting
			-- never reflows the line under the cursor.
			anti_conceal = { enabled = false },
			win_options = {
				-- Raw view: LazyVim's global conceallevel=2 would still hide `**` and
				-- link URLs through treesitter, so drop it to 0.
				conceallevel = { default = 0 },
				concealcursor = { rendered = "nvc" },
			},
			heading = {
				-- Default heading backgrounds link to Diff* groups: H1 is a solid
				-- yellow bar across the window. One faint band per heading instead,
				-- with the level carried by the foreground colour.
				width = "block",
				right_pad = 1,
				backgrounds = { "CursorLine" },
			},
		},
	},
}
