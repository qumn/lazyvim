return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    opts = {
      -- jdtls = function(opts)
      --   local install_path = require("mason-registry").get_package("jdtls"):get_install_path()
      --   local args = "-javaagent:" .. install_path .. "/lombok.jar"
      --   table.insert(opts.cmd, "--jvm-arg=" .. args)
      --   return opts
      -- end,
    },
  },
  {
    dir = vim.fn.stdpath("config") .. "/spring.nvim",
    name = "spring.nvim",
    cmd = "SpringEndpoints",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<Leader>sr", mode = "n", "<cmd>SpringEndpoints<cr>", desc = "List Spring Endpoints" },
    },
    config = function()
      require("spring").setup()
      require("telescope").load_extension("spring")
    end,
  },
}
