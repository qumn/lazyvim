return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      servers = {
        ["*"] = {
          keys = {
            { "gy", false },
            {
              "gt",
              function()
                require("telescope.builtin").lsp_type_definitions({ reuse_win = true })
              end,
              desc = "Goto [T]ype Definition",
            },
            { "gI", false },
            {
              "gi",
              function()
                require("telescope.builtin").lsp_implementations({ reuse_win = true })
              end,
              desc = "Goto Implementation",
            },
          },
        },
      },
    },
  },
}
