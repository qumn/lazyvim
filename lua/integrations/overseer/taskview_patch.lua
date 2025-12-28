local M = {}

function M.setup()
  local TaskView = require("overseer.task_view")
  if TaskView._open_output_keymaps_patched then
    return
  end
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

return M
