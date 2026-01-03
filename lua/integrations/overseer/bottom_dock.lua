local M = {}

function M.setup()
  local bottom = require("integrations.layout.bottom")
  local bottom_owner_overseer = "overseer_dock"

  local function hide_overseer_dock()
    local ok, window = pcall(require, "overseer.window")
    if ok and window.is_open() then
      window.close()
    end
  end

  local group = vim.api.nvim_create_augroup("OverseerBottomDock", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "OverseerList",
    callback = function()
      bottom.toggle({ id = bottom_owner_overseer, hide = hide_overseer_dock, claim = true })
    end,
  })
end

return M
