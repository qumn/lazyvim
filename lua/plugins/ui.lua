return {
  {
    "sainnhe/everforest",
    lazy = true,
    init = function()
      vim.g.everforest_diagnostic_virtual_text = "highlighted"
      vim.g.everforest_diagnostic_line_highlight = 1
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_disable_italic_comment = 1
    end,
  },

  {
    "brenoprata10/nvim-highlight-colors",
    event = "BufReadPre",
    config = function()
      require("nvim-highlight-colors").setup({
        render = "background", -- "background" | "foreground" | "virtual"
        enable_named_colors = false,
        enable_tailwind = false,
      })
    end,
  },
  {
    "s1n7ax/nvim-window-picker",
    name = "window-picker",
    event = "VeryLazy",
    version = "2.*",
    config = function()
      require("window-picker").setup()
    end,
  },
}
