return {
  "stevearc/overseer.nvim",
  dependencies = { { "m00qek/baleia.nvim", lazy = true } },
  cmd = { "OverseerRun", "OverseerToggle" },
  -- stylua: ignore
  keys = {
    { "<Leader>o",  mode = "n", desc = "Overseer" },
    { "<Leader>oa", mode = "n", "<cmd>OverseerQuickAction<cr>", desc = "Overseer quick action list" },
    { "<Leader>ot", mode = "n", "<cmd>OverseerToggle<cr>",      desc = "Toggle overseer task list" },
    { "<Leader>or", mode = "n", "<cmd>OverseerRun<cr>",         desc = "List overseer run templates" },
  },
  init = function()
    require("integrations.overseer.watch_run").setup()
  end,
  config = function()
    require("integrations.overseer.safe_win_jump").setup()

    local function clear_task_output()
      local ok_view, TaskView = pcall(require, "overseer.task_view")
      if not ok_view or not TaskView.task_under_cursor then
        return
      end
      local task = TaskView.task_under_cursor
      if not task then
        return
      end
      local bufnr = task:get_bufnr()
      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      local modifiable = vim.bo[bufnr].modifiable
      if not modifiable then
        vim.bo[bufnr].modifiable = true
      end
      pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, { "" })
      if not modifiable then
        vim.bo[bufnr].modifiable = false
      end
    end

    local opts = {
      dap = false,
      output = { use_terminal = false, preserve_width = true },
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
          ["t"] = {
            callback = function()
              require("integrations.overseer.tasklist_toggle").toggle_from_tasklist()
            end,
            desc = "Toggle task list",
          },
          ["<C-u>"] = "keymap.scroll_output_up",
          ["<C-d>"] = "keymap.scroll_output_down",
          ["<C-c>"] = { "keymap.run_action", opts = { action = "stop" }, desc = "Stop task" },
          ["<C-h>"] = false,
          ["<C-j>"] = false,
          ["<C-k>"] = false,
          ["<C-l>"] = { callback = clear_task_output, mode = "n", desc = "Clear task output" },
          ["r"] = {
            callback = function()
              require("integrations.overseer.restart").from_tasklist()
            end,
            desc = "Restart task",
          },
        },
      },
    }

    require("integrations.overseer.color_output").setup()
    require("integrations.overseer.exit_cleanup").setup()
    local overseer = require("overseer")
    overseer.setup(opts)
    overseer.add_template_hook(nil, function(task_defn, util)
      local existing
      for _, comp in ipairs(task_defn.components or {}) do
        if comp == "open_output_keymaps" then
          existing = {}
          break
        end
        if type(comp) == "table" and comp[1] == "open_output_keymaps" then
          existing = vim.deepcopy(comp)
          break
        end
      end
      local conf = existing or { "open_output_keymaps" }
      conf[1] = "open_output_keymaps"
      conf.on_start = "always"
      if conf.direction == nil then
        conf.direction = "dock"
      end
      util.add_component(task_defn, conf)
    end)
    require("integrations.overseer.bottom_dock").setup()
    require("integrations.overseer.taskview_patch").setup()
  end,
}
