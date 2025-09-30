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
      -- macos 指定远行 jdtls 的 jdk路径
      ---@diagnostic disable-next-line: undefined-field
      local uname = vim.loop.os_uname()
      if uname.sysname == "Darwin" then
        local java_home = vim.fn.system("/usr/libexec/java_home -v21"):gsub("%s+", "")
        table.insert(opts.cmd, "--java-executable=" .. java_home .. "/bin/java")
      end

      return vim.tbl_deep_extend("force", opts, {
        settings = {
          java = {
            configuration = {
              -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
              -- And search for `interface RuntimeOption`
              -- The `name` is NOT arbitrary, but must match one of the elements from `enum ExecutionEnvironment` in the link above
              runtimes = {
                {
                  name = "jdk8",
                  path = vim.fn.system("/usr/libexec/java_home -v1.8"):gsub("%s+", ""),
                },
                {
                  name = "jdk17",
                  path = vim.fn.system("/usr/libexec/java_home -v17"):gsub("%s+", ""),
                },
                {
                  name = "jdk21",
                  path = vim.fn.system("/usr/libexec/java_home -v21"):gsub("%s+", ""),
                },
              },
            },
          },
        },
      })
    end,
  },
}
