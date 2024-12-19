return {
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "storm" },
  },
  {
    -- "sainnhe/everforest",
    dir = "~/Workspace/lua/everforest",
    branch = "cstm",
    -- version = false,
    -- lazy = false,
    -- priority = 1000, -- make sure to load this before all the other start plugins
    -- Optional; default configuration will be used if setup isn't called.
    config = function() end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    event = "VeryLazy",
  },
  -- {
  --   "catppuccin/nvim",
  --   name = "catppuccin",
  --   opts = {
  --     flavour = "macchiato",
  --   },
  -- },
  --
  -- {
  --   "nvim-lualine/lualine.nvim",
  --   opts = {
  --     theme = "catppuccin",
  --   },
  -- },
  --
  -- -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "everforest",
    },
  },
}
