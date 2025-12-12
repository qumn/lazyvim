-- Neovim/Telescope glue: run rg (fast), parse via core, show picker.
local Job = require("plenary.job")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local core = require("spring.endpoints.core")

local M = {}

local function project_root()
  -- LazyVim root (git / lsp / markers)
  return require("lazyvim.util").root()
end

local function run_rg(root, on_done)
  local args = {
    "--no-heading",
    "--with-filename",
    "-n",
    "--glob",
    "**/src/main/java/**",
    "-g",
    "*Controller.java",
    "@(RequestMapping|GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)\\b",
    ".",
  }

  local lines = {}
  local errs = {}

  ---@diagnostic disable-next-line: missing-fields
  Job:new({
    command = "rg",
    args = args,
    cwd = root,
    on_stdout = function(_, line)
      if line and line ~= "" then
        table.insert(lines, line)
      end
    end,
    on_stderr = function(_, line)
      if line and line ~= "" then
        table.insert(errs, line)
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and code ~= 1 then
        vim.schedule(function()
          vim.notify("rg failed (" .. tostring(code) .. "):\n" .. table.concat(errs, "\n"), vim.log.levels.ERROR)
        end)
        return
      end

      vim.schedule(function()
        on_done(lines)
      end)
    end,
  }):start()
end

function M.endpoints_picker(opts)
  opts = opts or {}
  local root = project_root()

  run_rg(root, function(lines)
    local results = core.parse_rg_lines(lines, {
      -- If you ever need to tweak class-level detection, pass:
      -- class_level_pred = function(raw, trimmed) ... end
      class_level_pred = opts.class_level_pred,
    })

    pickers
      .new(opts, {
        prompt_title = "Spring Endpoints",
        finder = finders.new_table({
          results = results,
          entry_maker = function(e)
            local abs_file = e.file
            if not vim.loop.fs_realpath(abs_file) then
              abs_file = root .. "/" .. e.file:gsub("^%./", "")
            end

            local controller = abs_file:match("([^/]+Controller%.java)$") or abs_file:match("([^/]+)$")
            local display = string.format("%-6s %-45s %-30s", e.http, e.path, controller)
            return {
              value = e,
              display = display,
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
          end,
        }),
        sorter = conf.generic_sorter(opts),
        previewer = previewers.vim_buffer_vimgrep.new(opts),
        attach_mappings = function(prompt_bufnr, map)
          local function jump()
            local sel = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not sel then
              return
            end
            vim.cmd("edit " .. vim.fn.fnameescape(sel.filename))
            vim.api.nvim_win_set_cursor(0, { sel.lnum, 0 })
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
  end)
end

return M
