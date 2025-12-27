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
    require("integrations.overseer.color_output").setup()
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
      component_aliases = {
        default_vscode = {
          "default",
          {
            "open_output_keymaps",
            direction = "dock",
          },
        },
      },
    })

    local bottom = require("integrations.layout.bottom")
    local bottom_owner_overseer = "overseer_dock"

    local function hide_overseer_dock()
      local ok, window = pcall(require, "overseer.window")
      if ok and window.is_open() then
        window.close()
        bottom.clear(bottom_owner_overseer)
      end
    end

    local group = vim.api.nvim_create_augroup("OverseerBottomDock", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "OverseerList",
      callback = function()
        bottom.hide_other(bottom_owner_overseer)
        bottom.register(bottom_owner_overseer, hide_overseer_dock)
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "OverseerListClose",
      callback = function()
        bottom.clear(bottom_owner_overseer)
      end,
    })

    local TaskView = require("overseer.task_view")
    if not TaskView._open_output_keymaps_patched then
      TaskView._open_output_keymaps_patched = true
      local orig_update = TaskView.update
      local default_ft = require("overseer.component.open_output_keymaps").params.filetype.default
      function TaskView:update(...)
        orig_update(self, ...)
        if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
          return
        end
        local bufnr = vim.api.nvim_win_get_buf(self.winid)
        if vim.b[bufnr].overseer_task ~= -1 then
          return
        end
        if default_ft and default_ft ~= "" and vim.bo[bufnr].filetype == "" then
          vim.bo[bufnr].filetype = default_ft
        end
        if not vim.b[bufnr].open_output_keymaps_q then
          vim.b[bufnr].open_output_keymaps_q = true
          vim.keymap.set({ "n", "t" }, "q", function()
            local ok, window = pcall(require, "overseer.window")
            if ok and window.is_open() then
              window.close()
            else
              pcall(vim.cmd.close)
            end
          end, { buffer = bufnr, desc = "Close task list", silent = true, nowait = true })
        end
      end
    end
  end,
}
