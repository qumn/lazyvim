local M = {}

local Parser = require("integrations.overseer.stacktrace.parser")
local Workspace = require("integrations.overseer.stacktrace.workspace")
local Jdtls = require("integrations.overseer.stacktrace.jdtls")

local function safe_cmd(cmd)
  if type(cmd) ~= "string" or cmd == "" then
    return
  end
  pcall(function()
    vim.cmd(cmd)
  end)
end

local function focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
  if not (view and view.win and view.win.win and vim.api.nvim_win_is_valid(view.win.win)) then
    return
  end
  local bufnr = view.win.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if type(cursor_lnum) ~= "number" or cursor_lnum < 1 then
    return
  end

  local last = vim.api.nvim_buf_line_count(bufnr)
  local best_row = nil
  local best_diff = math.huge
  local best_side = 1

  for row = 1, last do
    local info = view.renderer and view.renderer:at(row) or nil
    local item = info and info.first_line and info.item or nil
    local qf = item and item.item or nil
    local ud = qf and qf.user_data or nil
    local stack_lnum = ud and type(ud) == "table" and ud.stacktrace_src_lnum or nil
    if stack_lnum then
      local diff = math.abs(stack_lnum - cursor_lnum)
      local side = (stack_lnum >= cursor_lnum) and 0 or 1
      if diff < best_diff or (diff == best_diff and side < best_side) then
        best_diff = diff
        best_side = side
        best_row = row
      end
    end
  end

  if best_row then
    pcall(vim.api.nvim_win_set_cursor, view.win.win, { best_row, 0 })
  end
end

local function hide_output_window(bufnr)
  local win = vim.api.nvim_get_current_win()
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.api.nvim_win_get_buf(win) ~= bufnr then
    return
  end
  if #vim.api.nvim_list_wins() > 1 then
    pcall(vim.api.nvim_win_close, win, true)
    return
  end
  safe_cmd("silent! keepalt buffer #")
end

local function bkey(ns, suffix)
  return ns .. "_" .. suffix
end

local function to_trouble_items(entries, placeholder_filename)
  local ok_item, TroubleItem = pcall(require, "trouble.item")
  if not ok_item or not TroubleItem then
    return {}
  end
  local items = {}
  placeholder_filename = placeholder_filename or "[stacktrace]"

  for _, e in ipairs(entries or {}) do
    local ud = e and e.user_data or nil
    local filename = (e and e.filename) or placeholder_filename
    local pos = { 1, 0 }
    if ud and type(ud) == "table" and ud.stacktrace_frame == true and ud.stacktrace_resolved == true and type(ud.lnum) == "number" then
      pos = { ud.lnum, 0 }
    end
    table.insert(
      items,
      TroubleItem.new({
        source = "stacktrace",
        filename = filename,
        pos = pos,
        end_pos = pos,
        item = e,
      })
    )
  end
  return items
end

local function build_session(opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0, nil
  end

  local ns = opts.namespace or "stacktrace"
  local cwd = opts.cwd or vim.fn.getcwd()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local entries = Parser.parse(lines)
  if #entries == 0 then
    return 0, nil
  end

  Workspace.resolve_items_in_place(entries, cwd)

  local id = string.format("%s:%d", ns, bufnr)
  local placeholder = string.format("[stacktrace-%s]", ns)
  local trouble_items = to_trouble_items(entries, placeholder)

  local ok_src, src = pcall(require, "trouble.sources.stacktrace")
  if not ok_src or not src then
    return 0, nil
  end

  src.set(id, trouble_items, {
    resolve_location = function(item, done)
      local qf = item and item.item or nil
      if qf then
        Workspace.resolve_items_in_place({ qf }, cwd)
        local ud = qf.user_data
        if ud and type(ud) == "table" and ud.stacktrace_resolved == true and type(qf.filename) == "string" and qf.filename ~= "" then
          item.filename = qf.filename
          local lnum = tonumber(ud.lnum) or 1
          item.pos = { lnum, 0 }
          item.end_pos = item.pos
          done(true)
          return
        end
      end
      Jdtls.resolve_location(item, done)
    end,
  })

  vim.b[bufnr][bkey(ns, "session_id")] = id
  vim.b[bufnr][bkey(ns, "last_line_count")] = vim.api.nvim_buf_line_count(bufnr)
  vim.b[bufnr][bkey(ns, "changedtick")] = vim.api.nvim_buf_get_changedtick(bufnr)

  return #trouble_items, id
end

function M.build_quickfix(opts)
  local count = build_session(opts)
  return count or 0
end

function M.build_and_open(opts)
  opts = opts or {}
  local bufnr = opts.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return 0
  end

  local ns = opts.namespace or "stacktrace"
  local cursor_lnum = opts.cursor_lnum
  local cursor_line = nil
  if type(cursor_lnum) == "number" and cursor_lnum >= 1 then
    cursor_line = vim.api.nvim_buf_get_lines(bufnr, cursor_lnum - 1, cursor_lnum, false)[1]
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local session_id = vim.b[bufnr][bkey(ns, "session_id")]

  local ok_src, src = pcall(require, "trouble.sources.stacktrace")
  if ok_src and src and session_id and src.sessions and src.sessions[session_id] then
    if vim.b[bufnr][bkey(ns, "last_line_count")] == line_count and vim.b[bufnr][bkey(ns, "changedtick")] == changedtick then
      local ok_trouble, trouble = pcall(require, "trouble")
      if ok_trouble and trouble then
        if opts.close_overseer ~= false then
          safe_cmd("silent! OverseerClose")
        end
        if opts.hide_output_window ~= false then
          hide_output_window(bufnr)
        end
        local view = trouble.open({
          mode = "stacktrace",
          focus = true,
          params = { id = session_id },
          win = { wo = { wrap = true, linebreak = true, breakindent = true } },
        })
        if view and view.wait then
          view:wait(function()
            if cursor_lnum and cursor_line and Parser.looks_like_stacktrace_line(cursor_line) then
              focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
            end
          end)
        end
        return 1
      end
    end
  end

  local built, id = build_session(opts)
  if not built or built == 0 or not id then
    return 0
  end

  local ok_trouble, trouble = pcall(require, "trouble")
  if not ok_trouble or not trouble then
    return built
  end

  if opts.close_overseer ~= false then
    safe_cmd("silent! OverseerClose")
  end
  if opts.hide_output_window ~= false then
    hide_output_window(bufnr)
  end

  local view = trouble.open({
    mode = "stacktrace",
    focus = true,
    params = { id = id },
    win = { wo = { wrap = true, linebreak = true, breakindent = true } },
  })
  if view and view.wait then
    view:wait(function()
      if cursor_lnum and cursor_line and Parser.looks_like_stacktrace_line(cursor_line) then
        focus_trouble_on_stacktrace_lnum(view, cursor_lnum)
      end
    end)
  end

  return built
end

return M
