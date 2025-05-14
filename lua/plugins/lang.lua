return {
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = function(_, opts)
      local Keys = require("lazyvim.plugins.lsp.keymaps").get()

      -- stylua: ignore start
      vim.list_extend(Keys, {
        { "gy", false },
        { "gt", function() require("telescope.builtin").lsp_type_definitions({ reuse_win = true }) end, desc = "Goto [T]ype Definition" },
        { "gI", false },
        { "gi", function() require("telescope.builtin").lsp_implementations({ reuse_win = true }) end, desc = "Goto Implementation" },
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
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      table.insert(opts.cmd, "--jvm-arg=-Djava.import.generatesMetadataFilesAtProjectRoot=false")
      table.insert(opts.cmd, "-Dlog.perf.level=OFF")

      print(vim.inspect(opts))
    end,
  },
}
