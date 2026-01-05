local M = {}

local function grep_globs_from_suffixes(label)
  local globs = {}
  local normalized = (label or ""):gsub("%s+", "")
  if normalized == "" then
    return globs
  end
  for ext in string.gmatch(normalized, "[^,%s]+") do
    local glob = ext
    if glob:sub(1, 1) == "." then
      glob = "*" .. glob
    else
      glob = "*." .. glob
    end
    table.insert(globs, glob)
  end
  return globs
end

local function telescope_find_command_fallback()
  if vim.fn.executable("rg") == 1 then
    return { "rg", "--files", "--color", "never" }
  end
  if vim.fn.executable("fd") == 1 then
    return { "fd", "--type", "f", "--color", "never" }
  end
  if vim.fn.executable("fdfind") == 1 then
    return { "fdfind", "--type", "f", "--color", "never" }
  end
  if vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
    return { "find", ".", "-type", "f" }
  end
  if vim.fn.executable("where") == 1 then
    return { "where", "/r", ".", "*" }
  end
end

local function add_command_globs(find_command, globs)
  local tool = find_command[1]
  if tool == "rg" or tool == "fd" or tool == "fdfind" then
    for _, glob in ipairs(globs) do
      table.insert(find_command, "--glob")
      table.insert(find_command, glob)
    end
    return find_command
  end

  if tool == "find" then
    table.insert(find_command, "(")
    for i, glob in ipairs(globs) do
      if i > 1 then
        table.insert(find_command, "-o")
      end
      table.insert(find_command, "-name")
      table.insert(find_command, glob)
    end
    table.insert(find_command, ")")
    return find_command
  end
end

local function telescope_kind(prompt_title)
  if prompt_title:find("Live Grep", 1, true) then
    return "live_grep"
  end
  if prompt_title:find("Find Files", 1, true) then
    return "find_files"
  end
end

local function telescope_default_suffixes(prompt_title)
  return prompt_title:match("^Live Grep %((.+)%)$") or prompt_title:match("^Find Files %((.+)%)$") or ""
end

function M.new(builtin)
  return function(prompt_bufnr)
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local picker = action_state.get_current_picker(prompt_bufnr)
    if not picker or type(picker.prompt_title) ~= "string" then
      return
    end

    local initial_mode = vim.api.nvim_get_mode().mode
    local current_line = action_state.get_current_line()
    local title = picker.prompt_title
    local kind = telescope_kind(title)
    if kind == nil then
      return
    end

    local default = telescope_default_suffixes(title)
    local input_opts = { prompt = "File suffixes (comma): " }
    if default ~= "" then
      input_opts.default = default
    end

    vim.ui.input(input_opts, function(input)
      if input == nil then
        return
      end

      local label = input:gsub("%s+", "")
      local globs = grep_globs_from_suffixes(label)
      local args = {}
      for _, glob in ipairs(globs) do
        table.insert(args, "-g")
        table.insert(args, glob)
      end

      actions.close(prompt_bufnr)
      vim.schedule(function()
        local cwd = picker.cwd
        local base_opts = { cwd = cwd }
        if initial_mode:sub(1, 1) == "i" then
          base_opts.initial_mode = "insert"
        else
          base_opts.initial_mode = "normal"
        end
        if current_line ~= "" then
          base_opts.default_text = current_line
        end

        if #globs == 0 then
          if kind == "live_grep" then
            builtin.live_grep(base_opts)
          else
            builtin.find_files(base_opts)
          end
          return
        end

        if kind == "live_grep" then
          builtin.live_grep(vim.tbl_extend("force", base_opts, {
            additional_args = function()
              return args
            end,
            prompt_title = "Live Grep (" .. label .. ")",
          }))
          return
        end

        local find_command = telescope_find_command_fallback()
        local with_globs = find_command and add_command_globs(find_command, globs)
        if not with_globs then
          vim.notify("find_files suffix filter requires rg/fd/find", vim.log.levels.WARN)
          builtin.find_files(base_opts)
          return
        end

        builtin.find_files(vim.tbl_extend("force", base_opts, {
          find_command = with_globs,
          prompt_title = "Find Files (" .. label .. ")",
        }))
      end)
    end)
  end
end

return M
