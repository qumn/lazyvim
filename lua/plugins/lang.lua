return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      setup = {
        rust_analyzer = function()
          return true
        end,
      },
    },
  },
}
