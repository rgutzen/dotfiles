return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      file_types = { "markdown" },
    },
  },
  -- Image preview dropped: herdr's kitty-graphics passthrough could not be
  -- verified headlessly, and snacks.image would otherwise emit escapes silently.
  { "folke/snacks.nvim", opts = { image = { enabled = false } } },
}
