return {
  {
    "mfussenegger/nvim-jdtls",
    ---@type lspconfig.options.jdtls
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      jdtls = function(opts)
        local install_path = require("mason-registry").get_package("jdtls"):get_install_path()
        local jvmArg = "-javaagent:" .. install_path .. "/lombok.jar"
        table.insert(opts.cmd, "--jvm-arg=" .. jvmArg)
        -- opts = vim.tbl_extend("force", opts, {
        --   settings = {
        --     java = {
        --       format = {
        --         enabled = true,
        --         settings = {
        --           url = "/Users/qumn/.config/LazyVim/rule/intellij-java-google-style.xml",
        --         },
        --       },
        --     },
        --   },
        -- })
        -- print(vim.inspect(opts))
        return opts
      end,
    },
  },
}
