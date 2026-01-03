local M = {}

function M.setup()
  local ok_util, util = pcall(require, "overseer.util")
  if not ok_util or type(util.go_win_no_au) ~= "function" then
    return
  end
  if util._safe_go_win_no_au_patched then
    return
  end
  util._safe_go_win_no_au_patched = true

  local orig = util.go_win_no_au
  -- A window id can become invalid between being captured and being jumped to (e.g. dock/terminal managers closing it).
  -- Guard the jump so Overseer window creation doesn't error when the original window disappears mid-flow.
  util.go_win_no_au = function(winid)
    if not winid or winid == 0 then
      return
    end
    local current_win = vim.api.nvim_get_current_win()
    if winid == current_win then
      return
    end
    if not vim.api.nvim_win_is_valid(winid) then
      return
    end
    return orig(winid)
  end
end

return M
