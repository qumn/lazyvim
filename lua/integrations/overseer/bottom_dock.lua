local M = {}

function M.setup()
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
end

return M
