return {
  -- {
  --   "folke/tokyonight.nvim",
  --   lazy = true,
  --   opts = { style = "storm" },
  -- },
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      vim.g.everforest_diagnostic_virtual_text = "highlighted"
      vim.g.everforest_diagnostic_line_highlight = 1
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_disable_italic_comment = 1
      vim.cmd([[colorscheme everforest]])
      require("config.highlight").load()
    end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    event = "VeryLazy",
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
