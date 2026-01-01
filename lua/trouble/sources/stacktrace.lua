---@diagnostic disable: inject-field
local Actions = require("trouble.config.actions")
local Preview = require("trouble.view.preview")

---@class trouble.Source.stacktrace.session
---@field id string
---@field items trouble.Item[]
---@field meta? table<string, any>

---@class trouble.Source.stacktrace: trouble.Source
local M = {}

---@type table<string, trouble.Source.stacktrace.session>
M.sessions = {}

M.last_id = nil

M._suppress_preview_until = 0

local function get_session_id(opts)
  opts = opts or {}
  local params = opts.params
  return params and params.id or nil
end

local function get_session(view)
  local opts = view and view.opts or {}
  local id = get_session_id(opts) or M.last_id
  return id and M.sessions[id] or nil
end

local function get_ud(item)
  local it = item and item.item or nil
  local ud = it and it.user_data or nil
  return (type(ud) == "table") and ud or nil
end

local function is_frame(item)
  local ud = get_ud(item)
  return ud and ud.stacktrace_frame == true
end

local function is_resolved(item)
  local ud = get_ud(item)
  return ud and ud.stacktrace_resolved == true
end

local function sanitize_item(item)
  if item and item.buf and not vim.api.nvim_buf_is_valid(item.buf) then
    item.buf = nil
    local ud = get_ud(item)
    if ud then
      ud.stacktrace_resolved = false
    end
  end
end

local function can_edit_file(filename)
  return type(filename) == "string" and filename ~= "" and vim.fn.filereadable(filename) == 1
end

local function jump_edit(view, item)
  local main = view and view:main() or nil
  local win = main and main.win or 0
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local filename = item and item.filename or nil
  if type(filename) == "string" and filename ~= "" and vim.fn.filereadable(filename) == 1 then
    vim.api.nvim_win_call(win, function()
      vim.cmd("normal! m'")
    end)
    vim.api.nvim_set_current_win(win)
    vim.cmd("silent! keepalt keepjumps edit " .. vim.fn.fnameescape(filename))

    local pos = item and item.pos or { 1, 0 }
    local lnum = tonumber(pos[1]) or 1
    local col = tonumber(pos[2]) or 0
    local last = vim.api.nvim_buf_line_count(0)
    lnum = math.min(math.max(lnum, 1), math.max(last, 1))
    pcall(vim.api.nvim_win_set_cursor, 0, { lnum, col })
    vim.cmd("norm! zzzv")
    return true
  end

  if item and item.buf and vim.api.nvim_buf_is_valid(item.buf) and view and view.jump then
    pcall(view.jump, view, item)
    return true
  end
  return false
end

local function suppress_preview(ms)
  local uv = vim.uv or vim.loop
  local now = uv and uv.now and uv.now() or 0
  M._suppress_preview_until = now + (ms or 250)
end

local function needs_resolution(item)
  if not (item and is_frame(item)) then
    return false
  end
  if is_resolved(item) then
    return false
  end
  if item.buf and vim.api.nvim_buf_is_valid(item.buf) then
    return false
  end
  if can_edit_file(item.filename) then
    return false
  end
  return true
end

local function resolve_frame(view, item, action, on_done)
  local session = get_session(view)
  local resolver = session and session.meta and session.meta.resolve_frame or nil
  if type(resolver) ~= "function" then
    return false
  end

  local function sync_session_item()
    if not session or not item then
      return
    end
    local nr = item.item and item.item.nr or nil
    for _, it in ipairs(session.items or {}) do
      if it == item or (nr and it and it.item and it.item.nr == nr) then
        it.buf = item.buf
        it.filename = item.filename
        it.pos = item.pos
        it.end_pos = item.end_pos
        return
      end
    end
  end

  resolver(view, item, action, function(ok)
    if type(on_done) == "function" then
      pcall(on_done, ok)
    end
    if not ok then
      return
    end
    sync_session_item()
    if item and item.cache and item.cache.clear then
      item.cache:clear()
    end
    if Preview.is_open() then
      Preview.close()
    end
    if view and view.render then
      view:render()
    end
    if action == "jump" then
      jump_edit(view, item)
      return
    end
    if action == "preview" and view and view.preview then
      view:preview(item)
    end
  end)
  return true
end

local function move_to_caused_by(view, direction)
  if not view or not view.win or not view.win.win or not vim.api.nvim_win_is_valid(view.win.win) then
    return
  end
  local bufnr = view.win.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(view.win.win)
  local start = cursor[1]
  local last = vim.api.nvim_buf_line_count(bufnr)

  local function is_caused_by_row(row)
    local info = view.renderer and view.renderer:at(row) or nil
    local item = info and info.first_line and info.item or nil
    local ud = get_ud(item)
    return ud and ud.stacktrace_caused_by == true
  end

  local function scan(from, to, step)
    for row = from, to, step do
      if is_caused_by_row(row) then
        pcall(vim.api.nvim_win_set_cursor, view.win.win, { row, 0 })
        return true
      end
    end
    return false
  end

  if direction > 0 then
    if scan(start + 1, last, 1) then
      return
    end
    scan(1, start - 1, 1)
  else
    if scan(start - 1, 1, -1) then
      return
    end
    scan(last, start + 1, -1)
  end
end

local function move_to_exception_group(view, direction)
  if not view or not view.win or not view.win.win or not vim.api.nvim_win_is_valid(view.win.win) then
    return
  end
  local bufnr = view.win.buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(view.win.win)
  local start = cursor[1]
  local last = vim.api.nvim_buf_line_count(bufnr)

  local function is_group_row(row)
    local info = view.renderer and view.renderer:at(row) or nil
    local node = info and info.first_line and info.node or nil
    return node and node.group ~= nil
  end

  local function is_item_row(row)
    local info = view.renderer and view.renderer:at(row) or nil
    return info and info.first_line and info.item ~= nil
  end

  local function current_group_row()
    for row = start, 1, -1 do
      if is_group_row(row) then
        return row
      end
    end
    return nil
  end

  local function first_item_row_in_group(group_row)
    if not group_row then
      return nil
    end
    for row = group_row + 1, last do
      if is_group_row(row) then
        return nil
      end
      if is_item_row(row) then
        return row
      end
    end
    return nil
  end

  local function scan(from, to, step)
    for row = from, to, step do
      if is_group_row(row) then
        local item_row = first_item_row_in_group(row) or row
        pcall(vim.api.nvim_win_set_cursor, view.win.win, { item_row, 0 })
        return true
      end
    end
    return false
  end

  local base = current_group_row() or start

  if direction > 0 then
    if scan(base + 1, last, 1) then
      return
    end
    scan(1, base - 1, 1)
  else
    if scan(base - 1, 1, -1) then
      return
    end
    scan(last, base + 1, -1)
  end
end

M.config = {
  modes = {
    stacktrace = {
      desc = "Stacktrace entries previously opened via `require('trouble.sources.stacktrace').open()`.",
      source = "stacktrace",
      focus = true,
      follow = false,
      auto_preview = true,
      preview = { type = "main", scratch = true },
      groups = {
        { "item.module", format = "{hl:Title}{item.module}{hl} {count}" },
      },
      sort = {
        function(item)
          local it = item and item.item or nil
          return it and it.nr or math.huge
        end,
      },
      formatters = {
        stacktrace_text = function(ctx)
          local qf = ctx and ctx.item and ctx.item.item or nil
          local text = qf and qf.text or (ctx and ctx.item and ctx.item.text) or ""
          local ud = (qf and type(qf.user_data) == "table") and qf.user_data or nil
          local item = ctx and ctx.item or nil

          text = text:gsub("^\t", "")

          if ud and ud.stacktrace_frame and text:match("^%s*at%s+") then
            text = text:gsub("%s*%b()%s*$", "")
            if type(ud.lnum) == "number" then
              text = text .. ":" .. tostring(ud.lnum)
            end
          end

          local hl = "TroubleStacktraceText"
          if ud and ud.stacktrace_caused_by == true then
            hl = "TroubleStacktraceCausedBy"
          elseif ud and ud.stacktrace_suppressed == true then
            hl = "TroubleStacktraceSuppressed"
          elseif ud and ud.stacktrace_ellipsis == true then
            hl = "TroubleStacktraceEllipsis"
          elseif ud and ud.stacktrace_frame == true then
            local resolved = ud.stacktrace_resolved == true
              or (item and item.buf and vim.api.nvim_buf_is_valid(item.buf))
            hl = resolved and "TroubleStacktraceFrameResolved" or "TroubleStacktraceFrameUnresolved"
          elseif text:match("^%s*Caused by:") then
            hl = "TroubleStacktraceCausedBy"
          elseif text:match("^%s*Suppressed:") then
            hl = "TroubleStacktraceSuppressed"
          elseif text:match("^%s*%.%.%.%s+%d+%s+more%s*$") then
            hl = "TroubleStacktraceEllipsis"
          end

          return { text = text, hl = hl }
        end,
      },
      format = "{severity_icon|item.type:DiagnosticSignWarn} {stacktrace_text}",
      keys = {
        ["[c"] = {
          action = function(view)
            move_to_caused_by(view, -1)
          end,
          desc = "Prev caused by",
        },
        ["]c"] = {
          action = function(view)
            move_to_caused_by(view, 1)
          end,
          desc = "Next caused by",
        },
        ["[e"] = {
          action = function(view)
            move_to_exception_group(view, -1)
          end,
          desc = "Prev exception",
        },
        ["]e"] = {
          action = function(view)
            move_to_exception_group(view, 1)
          end,
          desc = "Next exception",
        },
        ["<cr>"] = {
          action = function(view, ctx)
            local item = ctx and ctx.item or nil
            if not item then
              return Actions.jump(view, ctx)
            end
            sanitize_item(item)
            if not is_frame(item) then
              return
            end
            suppress_preview(400)
            if Preview.is_open() then
              Preview.close()
            end
            if needs_resolution(item) then
              local prev = view and view.opts and view.opts.auto_preview
              if view and view.opts then
                view.opts.auto_preview = false
              end
              if resolve_frame(view, item, "jump", function()
                if view and view.opts then
                  view.opts.auto_preview = prev
                end
              end) then
                return
              end
              if view and view.opts then
                view.opts.auto_preview = prev
              end
            end
            jump_edit(view, item)
          end,
          desc = "Jump",
        },
        p = {
          action = function(view, ctx)
            local item = ctx and ctx.item or nil
            if not item then
              return
            end
            sanitize_item(item)
            if needs_resolution(item) and resolve_frame(view, item, "preview") then
              return
            end
            Actions.preview(view, ctx)
          end,
          desc = "Preview",
        },
      },
    },
  },
}

function M.setup()
  vim.api.nvim_set_hl(0, "TroubleStacktraceFrameResolved", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "TroubleStacktraceFrameUnresolved", { link = "TroubleSource", default = true })
  vim.api.nvim_set_hl(0, "TroubleStacktraceCausedBy", { link = "DiagnosticWarn", default = true })
  vim.api.nvim_set_hl(0, "TroubleStacktraceSuppressed", { link = "DiagnosticHint", default = true })
  vim.api.nvim_set_hl(0, "TroubleStacktraceEllipsis", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "TroubleStacktraceText", { link = "TroubleText", default = true })
end

---@param id string
---@param items trouble.Item[]
---@param meta? table<string, any>
function M.set(id, items, meta)
  if type(id) ~= "string" or id == "" then
    return
  end
  M.sessions[id] = { id = id, items = items or {}, meta = meta or {} }
  M.last_id = id
end

---@param cb trouble.Source.Callback
---@param ctx trouble.Source.ctx
function M.get(cb, ctx)
  local id = (ctx and ctx.opts and ctx.opts.params and ctx.opts.params.id) or M.last_id
  local session = id and M.sessions[id] or nil
  cb(session and session.items or {})
end

function M.preview(_item, ctx)
  local uv = vim.uv or vim.loop
  local now = uv and uv.now and uv.now() or 0
  if now < (M._suppress_preview_until or 0) then
    if ctx and type(ctx.close) == "function" then
      ctx.close()
    end
    return
  end

  local item = _item
  if not item then
    return
  end
  if not (ctx and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf)) then
    return
  end

  local pos = item.pos
  if type(pos) ~= "table" then
    item.pos = { 1, 0 }
    pos = item.pos
  end
  local lnum = tonumber(pos[1]) or 1
  local col = tonumber(pos[2]) or 0
  local last = vim.api.nvim_buf_line_count(ctx.buf)
  lnum = math.min(math.max(lnum, 1), math.max(last, 1))
  col = math.max(col, 0)
  item.pos = { lnum, col }

  local end_pos = item.end_pos
  if type(end_pos) ~= "table" then
    item.end_pos = item.pos
    end_pos = item.end_pos
  end
  local end_lnum = tonumber(end_pos[1]) or lnum
  local end_col = tonumber(end_pos[2]) or col
  end_lnum = math.min(math.max(end_lnum, 1), math.max(last, 1))
  end_col = math.max(end_col, 0)
  item.end_pos = { end_lnum, end_col }
end

---@param opts? trouble.Mode|{items:trouble.Item[], id?:string, meta?:table<string,any>}|string
function M.open(opts)
  opts = opts or {}
  if type(opts) == "string" then
    opts = { mode = opts }
  end
  local id = opts.id or opts["session_id"] or "stacktrace"
  M.set(id, opts.items or {}, opts.meta)
  opts.params = vim.tbl_extend("force", opts.params or {}, { id = id })
  opts.mode = opts.mode or "stacktrace"
  require("trouble").open(opts)
end

return M
