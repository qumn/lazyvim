local M = {}

function M.diffview_fns(actions)
  if not actions then
    return {}
  end

  local lib = require("diffview.lib")
  local DiffView = require("diffview.scene.views.diff.diff_view").DiffView
  local RevType = require("diffview.vcs.rev").RevType

  ---@return any|nil
  local function get_view()
    local view = lib.get_current_view()
    if not (view and view:instanceof(DiffView)) then
      return nil
    end
    return view
  end

  local function get_layout(view)
    local layout = view.cur_layout
    if not (layout and layout.a and layout.b) then
      return nil
    end
    return layout
  end

  local function with_right_win(layout, fn)
    local right = layout and layout.b and layout.b.id
    if not right or not vim.api.nvim_win_is_valid(right) then
      return false
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_call(right, function()
      pcall(vim.api.nvim_win_set_cursor, right, cursor)
      fn(right)
    end)

    return true
  end

  local function smart_move(step, select, anchor)
    local before = vim.api.nvim_win_get_cursor(0)
    vim.cmd("normal! " .. step)
    local after = vim.api.nvim_win_get_cursor(0)
    if before[1] == after[1] and before[2] == after[2] then
      select()
      vim.cmd("normal! " .. anchor)
      vim.cmd("normal! " .. step)
    end
  end

  local function smart_next()
    smart_move("]c", actions.select_next_entry, "gg")
  end

  local function smart_prev()
    smart_move("[c", actions.select_prev_entry, "G")
  end

  local function diff2_discard()
    local view = get_view()
    if not view then
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

    local layout = get_layout(view)
    if not layout then
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
    local view = get_view()
    if not view then
      return
    end

    local layout = get_layout(view)
    if not (layout and layout.a.file and layout.b.file) then
      return
    end

    local left_rev = layout.a.file.rev
    local right_rev = layout.b.file.rev
    if not (left_rev and right_rev) then
      return
    end

    local cmd
    if right_rev.type == RevType.STAGE and left_rev.type == RevType.COMMIT then
      cmd = "diffget"
    else
      cmd = "diffput"
    end

    with_right_win(layout, function()
      vim.cmd(cmd)
    end)
  end

  local function diff2_write_both()
    local view = get_view()
    if not view then
      return
    end

    local layout = get_layout(view)
    if not (layout and layout.a.file and layout.b.file) then
      return
    end

    local function with_eventignore(events, fn)
      local prev = vim.o.eventignore
      local next_ignore = prev
      for _, ev in ipairs(events) do
        if not next_ignore:match("(^|,)" .. ev .. "($|,)") then
          next_ignore = (next_ignore == "" and ev) or (next_ignore .. "," .. ev)
        end
      end
      vim.o.eventignore = next_ignore
      pcall(fn)
      vim.o.eventignore = prev
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
        -- prevent autofrmat or other write autocmds from interfering
        with_eventignore({ "BufWritePre", "BufWritePost" }, function()
          vim.cmd("write")
        end)
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
