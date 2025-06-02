return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    opts = {
      jdtls = function(opts)
        local install_path = require("mason-registry").get_package("jdtls"):get_install_path()
        local args = "-javaagent:" .. install_path .. "/lombok.jar"
        table.insert(opts.cmd, "--jvm-arg=" .. args)
        return opts
      end,
    },
  },
}
