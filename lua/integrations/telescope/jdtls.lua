local uri = require("integrations.jdtls.uri")

local M = {}

local function qflist_previewer_with_jdt(previewer_opts)
  previewer_opts = previewer_opts or {}

  local from_entry = require("telescope.from_entry")
  local previewers = require("telescope.previewers")
  local telescope_conf = require("telescope.config").values

  local function jump_to_location(self, bufnr, entry)
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
        display_string = display_string .. ":" .. text
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

function M.setup(builtin)
  builtin.lsp_references = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_references)
  builtin.lsp_definitions = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_definitions)
  builtin.lsp_type_definitions = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_type_definitions)
  builtin.lsp_implementations = wrap_lsp_picker_with_jdt_entry_maker(builtin.lsp_implementations)

  return qflist_previewer_with_jdt
end

return M

