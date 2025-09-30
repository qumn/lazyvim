return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle" },
  keys = {
    { "<Leader>o", mode = "n", desc = "Overseer" },
    { "<Leader>oa", mode = "n", "<cmd>OverseerQuickAction<cr>", desc = "Overseer quick action list" },
    { "<Leader>ot", mode = "n", "<cmd>OverseerToggle<cr>", desc = "Toggle overseer task list" },
    { "<Leader>or", mode = "n", "<cmd>OverseerRun<cr>", desc = "List overseer run templates" },
  },
  config = function()
    local overseer = require("overseer")
    overseer.setup({
      dap = false,
      templates = { "builtin", "user.run_script" },
      task_list = {
        direction = "right",
        bindings = {
          ["i"] = "PrevTask",
          ["n"] = "NextTask",
          ["+"] = "IncreaseDetail",
          ["_"] = "DecreaseDetail",
          ["="] = "IncreaseAllDetail",
          ["-"] = "DecreaseAllDetail",
          ["t"] = "<CMD>OverseerQuickAction open tab<CR>",
          ["<C-u>"] = false,
          ["<C-d>"] = false,
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["<C-l>"] = false,
        },
      },
    })
  end,
  init = function()
    vim.api.nvim_create_user_command("WatchRun", function()
      local overseer = require("overseer")
      overseer.run_template({ name = "run script" }, function(task)
        if task then
          task:add_component({ "restart_on_save", paths = { vim.fn.expand("%:p") } })
          local main_win = vim.api.nvim_get_current_win()
          overseer.run_action(task, "open hsplit")
          vim.api.nvim_set_current_win(main_win)
        else
          vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
        end
      end)
    end, {})
  end,
}
