return {
  "stevearc/overseer.nvim",
  cmd = { "OverseerRun", "OverseerToggle" },
  -- stylua: ignore
  keys = {
    { "<Leader>o",  mode = "n", desc = "Overseer" },
    { "<Leader>oa", mode = "n", "<cmd>OverseerQuickAction<cr>", desc = "Overseer quick action list" },
    { "<Leader>ot", mode = "n", "<cmd>OverseerToggle<cr>",      desc = "Toggle overseer task list" },
    { "<Leader>or", mode = "n", "<cmd>OverseerRun<cr>",         desc = "List overseer run templates" },
  },
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
  config = function()
    local overseer = require("overseer")

    -- make spring-boot:run tasks unique,
    -- so that OverseerRun would behave like Restart
    overseer.add_template_hook({}, function(task_defn, util)
      local text = vim.fn.string({ task_defn.cmd, task_defn.args })

      if text:find("spring-boot:run", 1, true) then
        util.add_component(task_defn, { "unique", replace = true })
      else
      end
    end)

    overseer.setup({
      dap = false,
      output = { use_terminal = true, preserve_width = true },
      templates = { "builtin", "user.run_script" },
      task_list = {
        direction = "bottom",
        min_height = 20,
        max_height = { 40, 0.4 },
        keymaps = {
          ["i"] = "keymap.prev_task",
          ["n"] = "keymap.next_task",
          ["{"] = "keymap.prev_task",
          ["}"] = "keymap.next_task",

          ["t"] = "<CMD>OverseerQuickAction open tab<CR>",

          ["<C-u>"] = "keymap.scroll_output_up",
          ["<C-d>"] = "keymap.scroll_output_down",
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["<C-l>"] = false,
        },
      },
      component_aliases = {
        default_vscode = {
          "default",
          { "open_output", direction = "dock" },
        },
      },
    })
  end,
}
