-- Neovim/Telescope glue: stream rg, parse via core, show picker.
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local spring = require("spring")
local core = require("spring.endpoints.core")

local METHOD_PATTERN = [[\v^\s*(public|protected|private)?\s*(static\s+)?[[:alnum:]_<>\[\]$.]+\s+\zs[[:alnum:]_]+\s*\(]]

local M = {}

local function project_root()
  -- LazyVim root (git / lsp / markers)
  return require("lazyvim.util").root()
end

local function rg_args()
  return {
    "--no-heading",
    "--with-filename",
    "-n",
    "--g",
    "**/src/main/java/**/*Controller.java",
    "@(RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\\b",
    ".",
  }
end

local function resolve_opts(opts)
  if spring.get_opts then
    return spring.get_opts(opts)
  end
  return vim.tbl_deep_extend("force", spring.defaults or {}, opts or {})
end

local function make_displayer()
  return entry_display.create({
    separator = " ",
    items = {
      { width = 6 },
      { width = 45 },
      { remaining = true },
    },
  })
end

local function make_entry_maker(root, displayer, hl_http)
  return function(e)
    local abs_file = e.file
    if not vim.loop.fs_realpath(abs_file) then
      abs_file = root .. "/" .. e.file:gsub("^%./", "")
    end

    local controller = abs_file:match("([^/]+Controller%.java)$") or abs_file:match("([^/]+)$")
    local method_hl = hl_http[e.http] or hl_http.ANY or hl_http[""] or nil

    return {
      value = e,
      display = function()
        return displayer({
          { e.http, method_hl },
          e.path,
          controller,
        })
      end,
      ordinal = table.concat({
        e.http or "",
        e.path or "",
        controller or "",
      }, " "),
      filename = abs_file,
      lnum = e.lnum,
      col = 1,
      text = e.text or "",
    }
  end
end

local function jump_to_method(entry)
  if not entry then
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(entry.filename))

  local win = vim.api.nvim_get_current_win()
  local start = entry.lnum or 1
  vim.api.nvim_win_set_cursor(win, { start, 0 })

  local pos = vim.fn.searchpos(METHOD_PATTERN, "cnW")
  local line = (pos[1] and pos[1] > 0) and pos[1] or start
  local col = (pos[2] and pos[2] > 0) and (pos[2] - 1) or 0

  vim.api.nvim_win_set_cursor(win, { line, col })
end

local function make_streaming_finder(root, entry_builder)
  local state = core.new_stream_state()

  local function line_to_entry(line)
    local endpoint = core.ingest_line(state, line)
    if endpoint then
      return entry_builder(endpoint)
    end
  end

  local cmd = { "rg" }
  for _, arg in ipairs(rg_args()) do
    cmd[#cmd + 1] = arg
  end

  return finders.new_oneshot_job(cmd, {
    entry_maker = line_to_entry,
    cwd = root,
  })
end

function M.endpoints_picker(opts)
  opts = opts or {}
  local merged_opts = resolve_opts(opts)
  local root = project_root()

  local hl_http = merged_opts.hl_http or {}
  local displayer = make_displayer()
  local entry_maker = make_entry_maker(root, displayer, hl_http)
  local finder = make_streaming_finder(root, entry_maker)

  pickers
    .new(opts, {
      prompt_title = "Spring Endpoints",
      finder = finder,
      sorter = conf.generic_sorter(opts),
      previewer = previewers.vim_buffer_vimgrep.new(opts),
      attach_mappings = function(prompt_bufnr, map)
        local function jump()
          local sel = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          jump_to_method(sel)
        end

        local function copy()
          local sel = action_state.get_selected_entry()
          if not sel then
            return
          end
          local e = sel.value
          local s = string.format("%s %s", e.http, e.path)
          vim.fn.setreg("+", s)
          vim.notify("Copied: " .. s)
        end

        map("i", "<CR>", jump)
        map("n", "<CR>", jump)
        map("i", "<C-y>", copy)
        map("n", "<C-y>", copy)

        return true
      end,
    })
    :find()
end

return M
