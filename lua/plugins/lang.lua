return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = function(_, opts)
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()

      -- stylua: ignore start
      vim.list_extend(Keys, {
        { "gy", false },
        { "gt", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto T[y]pe Definition" },
      })
      -- stylua: ignore end

      return vim.tbl_deep_extend("force", opts, {
        setup = {
          rust_analyzer = function()
            return true
          end,
        },
      })
    end,
  },
}
