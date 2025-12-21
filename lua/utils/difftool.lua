local M = {}

function M.diffview_fns(actions)
  if not actions then
    return {}
  end

  local lib = require("diffview.lib")
  local DiffView = require("diffview.scene.views.diff.diff_view").DiffView
  local RevType = require("diffview.vcs.rev").RevType

  local function smart_next()
    local before = vim.api.nvim_win_get_cursor(0)
    vim.cmd("normal! ]c")
    local after = vim.api.nvim_win_get_cursor(0)
    if before[1] == after[1] and before[2] == after[2] then
      actions.select_next_entry()
      vim.cmd("normal! gg")
      vim.cmd("normal! ]c")
    end
  end

  local function smart_prev()
    local before = vim.api.nvim_win_get_cursor(0)
    vim.cmd("normal! [c")
    local after = vim.api.nvim_win_get_cursor(0)
    if before[1] == after[1] and before[2] == after[2] then
      actions.select_prev_entry()
      vim.cmd("normal! G")
      vim.cmd("normal! [c")
    end
  end

  local function with_right_win(layout, fn)
    if not (layout and layout.b and layout.b.id) then
      return false
    end

    local right_win = layout.b.id
    if not vim.api.nvim_win_is_valid(right_win) then
      return false
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_call(right_win, function()
      pcall(vim.api.nvim_win_set_cursor, right_win, cursor)
      fn(right_win)
    end)

    return true
  end

  local function diff2_discard()
    ---@type any
    local view = lib.get_current_view()
    if not (view and view:instanceof(DiffView)) then
      return
    end

    local file = view:infer_cur_file(false) or view.cur_entry
    if not file then
      return
    end

    if file.status == "?" then
      local ok = vim.fn.delete(file.absolute_path, "rf")
      if ok == 0 then
        actions.refresh_files()
      else
        vim.notify(("Failed to delete: %s"):format(file.absolute_path), vim.log.levels.ERROR)
      end
      return
    end

    local layout = view.cur_layout
    if not (layout and layout.a and layout.b) then
      return
    end

    local left_buf = layout.a.file and layout.a.file.bufnr
    if not (left_buf and vim.api.nvim_buf_is_valid(left_buf)) then
      return
    end

    if not with_right_win(layout, function()
      vim.cmd("diffget " .. left_buf)
    end) then
      return
    end

    layout:sync_scroll()
  end

  local function diff2_stage()
    ---@type any
    local view = lib.get_current_view()
    if not (view and view:instanceof(DiffView)) then
      return
    end

    local layout = view.cur_layout
    if not (layout and layout.a and layout.b and layout.a.file and layout.b.file) then
      return
    end

    local left_rev = layout.a.file.rev
    local right_rev = layout.b.file.rev
    if not (left_rev and right_rev) then
      return
    end

    if right_rev.type == RevType.STAGE and left_rev.type == RevType.COMMIT then
      with_right_win(layout, function()
        vim.cmd("diffget")
      end)
    else
      with_right_win(layout, function()
        vim.cmd("diffput")
      end)
    end
  end

  local function diff2_write_both()
    ---@type any
    local view = lib.get_current_view()
    if not (view and view:instanceof(DiffView)) then
      return
    end

    local layout = view.cur_layout
    if not (layout and layout.a and layout.b and layout.a.file and layout.b.file) then
      return
    end

    local function write_win(win, file)
      if not (win and file and file.rev) then
        return
      end
      local rtype = file.rev.type
      if rtype ~= RevType.LOCAL and rtype ~= RevType.STAGE then
        return
      end
      if not vim.api.nvim_win_is_valid(win.id) then
        return
      end
      vim.api.nvim_win_call(win.id, function()
        local prev = vim.o.eventignore
        local next_ignore = prev
        if not next_ignore:match("(^|,)BufWritePre($|,)") then
          next_ignore = (next_ignore == "" and "BufWritePre") or (next_ignore .. ",BufWritePre")
        end
        if not next_ignore:match("(^|,)BufWritePost($|,)") then
          next_ignore = (next_ignore == "" and "BufWritePost") or (next_ignore .. ",BufWritePost")
        end
        vim.o.eventignore = next_ignore
        pcall(vim.cmd, "write")
        vim.o.eventignore = prev
      end)
    end

    write_win(layout.a, layout.a.file)
    write_win(layout.b, layout.b.file)
  end

  return {
    smart_next = smart_next,
    smart_prev = smart_prev,
    diff2_discard = diff2_discard,
    diff2_stage = diff2_stage,
    diff2_write_both = diff2_write_both,
  }
end

return M
