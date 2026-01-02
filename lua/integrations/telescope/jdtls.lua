local uri = require("integrations.jdtls.uri")

local M = {}

local preview_ns = vim.api.nvim_create_namespace("telescope-jdtls-preview")

local function canonical_jdt_uri(name)
  if type(name) ~= "string" then
    return nil
  end
  if not name:match("^jdt:") then
    return nil
  end
  if name:match("^jdt://") then
    return name
  end
  local rest = name:sub(5)
  rest = rest:gsub("^/+", "")
  return "jdt://" .. rest
end

local function qflist_previewer_with_jdt(previewer_opts)
  previewer_opts = previewer_opts or {}

  local from_entry = require("telescope.from_entry")
  local previewers = require("telescope.previewers")
  local telescope_conf = require("telescope.config").values

  local function jump_to_location(self, bufnr, entry)
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, preview_ns, 0, -1)
      if entry.lnum and entry.lnum > 0 then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, preview_ns, entry.lnum - 1, 0, {
          end_row = entry.lnum - 1,
          end_col = 0,
          hl_group = "TelescopePreviewLine",
          hl_eol = true,
        })
      end
    end
    if not entry.lnum or entry.lnum <= 0 then
      return
    end
    local col = math.max((entry.col or 1) - 1, 0)
    pcall(vim.api.nvim_win_set_cursor, self.state.winid, { entry.lnum, col })
    if bufnr ~= nil then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("norm! zz")
      end)
    end
  end

  return previewers.new_buffer_previewer({
    title = "Preview",
    dyn_title = function(_, entry)
      return from_entry.path(entry, false, false)
    end,
    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, false, false)
    end,
    define_preview = function(self, entry)
      local raw = from_entry.path(entry, false, false)
      if not raw or raw == "" then
        return
      end

      if vim.startswith(raw, "jdt://") then
        local ok, jdtls = pcall(require, "jdtls")
        if ok then
          if self.state.bufname ~= raw then
            pcall(vim.api.nvim_buf_call, self.state.bufnr, function()
              jdtls.open_classfile(raw)
            end)
          end
          jump_to_location(self, self.state.bufnr, entry)
        end
        return
      end

      local p = from_entry.path(entry, true, false)
      if not p or p == "" then
        return
      end

      telescope_conf.buffer_previewer_maker(p, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        preview = previewer_opts.preview,
        callback = function(bufnr)
          jump_to_location(self, bufnr, entry)
        end,
        file_encoding = previewer_opts.file_encoding,
      })
    end,
  })
end

local function gen_quickfix_entry_maker_with_jdt(opts_for_entry)
  local make_entry = require("telescope.make_entry")
  local telescope_utils = require("telescope.utils")

  local base = make_entry.gen_from_quickfix(opts_for_entry)
  local show_line = vim.F.if_nil(opts_for_entry.show_line, true)
  local hidden = telescope_utils.is_path_hidden(opts_for_entry)

  return function(entry)
    local e = base(entry)
    local parsed = uri.parse(e.filename)
    if not parsed then
      return e
    end

    e.ordinal = (not hidden and parsed.label or "") .. " " .. e.text
    e.display = function()
      local display_string
      if hidden then
        display_string = string.format("%4d:%2d", e.lnum, e.col)
      else
        display_string = string.format("%s:%d:%d", parsed.label, e.lnum, e.col)
      end
      if show_line then
        local text = e.text:gsub(".* | ", "")
        if text ~= "" then
          display_string = display_string .. ":" .. text
        end
      end

      if hidden then
        return display_string, {}
      end

      local label_len = #parsed.label
      local tail_len = #parsed.tail
      return display_string, {
        { { tail_len, label_len }, "TelescopeResultsComment" },
      }
    end

    return e
  end
end

local function wrap_lsp_picker_with_jdt_entry_maker(fn)
  return function(o)
    o = o or {}
    if o.entry_maker == nil then
      o.entry_maker = gen_quickfix_entry_maker_with_jdt(o)
    end
    return fn(o)
  end
end

local function client_position_params(nvim011, win, extra)
  win = win or vim.api.nvim_get_current_win()
  if not nvim011 then
    local params = vim.lsp.util.make_position_params(win, "utf-16")
    if extra then
      params = vim.tbl_extend("force", params, extra)
    end
    return params
  end
  return function(client)
    local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
    if extra then
      params = vim.tbl_extend("force", params, extra)
    end
    return params
  end
end

local function is_file_uri(u)
  return type(u) == "string" and u:match("^file://") ~= nil
end

local function safe_byteindex(line, encoding, char_index)
  if not line or line == "" then
    return 0
  end
  local ok, idx = pcall(vim.str_byteindex, line, encoding, char_index, false)
  if ok and type(idx) == "number" then
    return idx
  end
  return math.min(#line, math.max(char_index, 0))
end

local function sort_reference_items(items)
  table.sort(items, function(a, b)
    local af = a.filename or ""
    local bf = b.filename or ""
    local ar = af:match("^jdt:") and 1 or 0
    local br = bf:match("^jdt:") and 1 or 0
    if ar ~= br then
      return ar < br
    end
    if af ~= bf then
      return af < bf
    end
    if (a.lnum or 0) ~= (b.lnum or 0) then
      return (a.lnum or 0) < (b.lnum or 0)
    end
    return (a.col or 0) < (b.col or 0)
  end)
end

local function fetch_many_jdt_contents(client, uris, on_progress, cb)
  if #uris == 0 then
    return cb({})
  end

  local results = {} ---@type table<string, string[]?>
  local total = #uris
  local pending = total

  for _, u in ipairs(uris) do
    client:request("java/classFileContents", { uri = u }, function(err, result)
      if not err and type(result) == "string" then
        local normalized = result:gsub("\r\n", "\n")
        results[u] = vim.split(normalized, "\n", { plain = true })
      end

      pending = pending - 1
      local done = total - pending
      if type(on_progress) == "function" then
        on_progress(done, total)
      end

      if pending == 0 then
        cb(results)
      end
    end, 0)
  end
end

-- Build items without reading `jdt://` buffer lines; buffer population triggers jdtls redraws and UI flicker.
-- `java/classFileContents` provides the line text needed for display/preview without opening the URI buffer.
---@param client vim.lsp.Client
---@param locs lsp.Location[]|lsp.LocationLink[]
---@param encoding string
---@param report? fun(done:number, total:number)
---@param cb fun(items: vim.quickfix.entry[])
local function locations_to_items_with_jdt_text(client, locs, encoding, report, cb)
  local items = {} ---@type vim.quickfix.entry[]
  local file_locs = {}
  local jdt_by_uri = {} ---@type table<string, lsp.Location[]|lsp.LocationLink[]>

  for _, loc in ipairs(locs) do
    local u = loc.uri or loc.targetUri
    if is_file_uri(u) then
      table.insert(file_locs, loc)
    else
      local jdt_uri = canonical_jdt_uri(u) or u
      if type(jdt_uri) == "string" and jdt_uri:match("^jdt:") then
        jdt_by_uri[jdt_uri] = jdt_by_uri[jdt_uri] or {}
        table.insert(jdt_by_uri[jdt_uri], loc)
      else
        local range = loc.range or loc.targetSelectionRange
        items[#items + 1] = {
          filename = jdt_uri,
          lnum = range.start.line + 1,
          col = range.start.character + 1,
          text = "",
          user_data = loc,
        }
      end
    end
  end

  if #file_locs > 0 then
    vim.list_extend(items, vim.lsp.util.locations_to_items(file_locs, encoding))
  end

  local uris = vim.tbl_keys(jdt_by_uri)
  table.sort(uris)

  fetch_many_jdt_contents(client, uris, report, function(contents)
    for _, u in ipairs(uris) do
      local lines = contents[u]
      for _, loc in ipairs(jdt_by_uri[u]) do
        local range = loc.range or loc.targetSelectionRange
        local row = range.start.line
        local end_row = range["end"].line
        local line = (lines and lines[row + 1]) or ""
        local end_line = (lines and lines[end_row + 1]) or ""
        local col0 = safe_byteindex(line, encoding, range.start.character)
        local end_col0 = safe_byteindex(end_line, encoding, range["end"].character)

        items[#items + 1] = {
          filename = u,
          lnum = row + 1,
          end_lnum = end_row + 1,
          col = col0 + 1,
          end_col = end_col0 + 1,
          text = line,
          user_data = loc,
        }
      end
    end
    cb(items)
  end)
end

local function with_lsp_progress(bufnr, title)
  local handler = vim.lsp.handlers["$/progress"]
  if type(handler) ~= "function" then
    return nil
  end

  local client = (vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1])
    or (vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/references" })[1])

  if not client then
    return nil
  end

  local token = tostring(vim.uv and vim.uv.hrtime() or (vim.loop and vim.loop.hrtime()) or os.clock())
  local begun = false
  local uv = vim.uv or vim.loop
  local timer = uv and uv.new_timer and uv.new_timer()
  if not timer then
    return nil
  end

  local function safe_close_timer()
    if not timer then
      return
    end
    pcall(timer.stop, timer)
    pcall(timer.close, timer)
    timer = nil
  end

  timer:start(120, 0, function()
    vim.schedule(function()
      begun = true
      handler(nil, {
        token = token,
        value = {
          kind = "begin",
          title = "Searching...",
          message = title,
          percentage = 0,
        },
      }, { client_id = client.id, method = "$/progress" })
      safe_close_timer()
    end)
  end)

  local function report(percentage, message)
    if not begun then
      return
    end
    vim.schedule(function()
      handler(nil, {
        token = token,
        value = {
          kind = "report",
          percentage = percentage,
          message = message or title,
        },
      }, { client_id = client.id, method = "$/progress" })
    end)
  end

  local function done()
    safe_close_timer()
    if not begun then
      return
    end
    vim.schedule(function()
      handler(nil, {
        token = token,
        value = {
          kind = "end",
          message = title,
        },
      }, { client_id = client.id, method = "$/progress" })
    end)
  end

  return {
    report = report,
    done = done,
  }
end

-- Avoid flicker caused by reading `jdt://` buffers during list construction; use classfile contents instead.
local function lsp_references_no_flicker()
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local utils = require("telescope.utils")

  local nvim011 = utils.nvim011

  return function(opts)
    opts = opts or {}
    opts.reuse_win = vim.F.if_nil(opts.reuse_win, false)
    opts.bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    opts.winnr = opts.winnr or vim.api.nvim_get_current_win()
    opts.curr_filepath = vim.api.nvim_buf_get_name(opts.bufnr)
    opts.include_current_line = vim.F.if_nil(opts.include_current_line, false)

    local params = client_position_params(nvim011, opts.winnr, {
      context = { includeDeclaration = vim.F.if_nil(opts.include_declaration, true) },
    })

    local progress = with_lsp_progress(opts.bufnr, "LSP References")

    local clients = vim.lsp.get_clients({ bufnr = opts.bufnr, method = "textDocument/references" })
    if not clients or vim.tbl_isempty(clients) then
      vim.notify("No LSP client supports references", vim.log.levels.INFO)
      if progress then
        progress.done()
      end
      return
    end

    vim.lsp.buf_request_all(opts.bufnr, "textDocument/references", params, function(results_per_client)
      local first_encoding
      local errors = {}
      local pending = 0
      local items = {} ---@type vim.quickfix.entry[]

      local function finish()
        if pending > 0 then
          return
        end

        if not opts.include_current_line then
          local lnum = vim.api.nvim_win_get_cursor(opts.winnr)[1]
          items = vim.tbl_filter(function(v)
            return not (v.filename == opts.curr_filepath and v.lnum == lnum)
          end, items)
        end

        if vim.tbl_isempty(items) then
          utils.notify("builtin.lsp_references", { msg = "No LSP References found", level = "INFO" })
          if progress then
            progress.done()
          end
          return
        end

        sort_reference_items(items)

        if #items == 1 and opts.jump_type ~= "never" and first_encoding then
          vim.lsp.util.show_document(items[1].user_data, first_encoding, { reuse_win = opts.reuse_win })
          if progress then
            progress.done()
          end
          return
        end

        if progress then
          progress.done()
        end

        pickers
          .new(opts, {
            prompt_title = "LSP References",
            finder = finders.new_table({
              results = items,
              entry_maker = opts.entry_maker or gen_quickfix_entry_maker_with_jdt(opts),
            }),
            previewer = conf.qflist_previewer(opts),
            sorter = conf.generic_sorter(opts),
            push_cursor_on_edit = true,
            push_tagstack_on_edit = true,
          })
          :find()
      end

      for client_id, result_or_error in pairs(results_per_client) do
        local error, result = result_or_error.err, result_or_error.result
        if error then
          errors[client_id] = error
        elseif result ~= nil and result ~= vim.NIL then
          local locations = {}
          if not vim.islist(result) then
            vim.list_extend(locations, { result })
          else
            vim.list_extend(locations, result)
          end

          local client = vim.lsp.get_client_by_id(client_id)
          local offset_encoding = client and client.offset_encoding or "utf-16"

          if not vim.tbl_isempty(locations) then
            first_encoding = first_encoding or offset_encoding
          end

          if client and client.name == "jdtls" then
            pending = pending + 1
            locations_to_items_with_jdt_text(client, locations, offset_encoding, function(done, total)
              if progress and progress.report and total > 0 then
                local pct = math.floor((done / total) * 100)
                progress.report(pct, "Fetching sources...")
              end
            end, function(client_items)
              vim.list_extend(items, client_items)
              pending = pending - 1
              finish()
            end)
          else
            vim.list_extend(items, vim.lsp.util.locations_to_items(locations, offset_encoding))
          end
        end
      end

      for _, error in pairs(errors) do
        utils.notify("builtin.lsp_references", { msg = "textDocument/references : " .. error.message, level = "ERROR" })
      end

      finish()
    end)
  end
end

function M.setup(builtin)
  builtin.lsp_references = lsp_references_no_flicker()
  builtin.lsp_definitions = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_definitions)
  builtin.lsp_type_definitions = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_type_definitions)
  builtin.lsp_implementations = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_implementations)

  return qflist_previewer_with_jdt
end

return M
