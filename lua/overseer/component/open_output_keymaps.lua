local constants = require("overseer.constants")
local STATUS = constants.STATUS

---@param bufnr integer|nil
local function clear_output_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local modifiable = vim.bo[bufnr].modifiable
  if not modifiable then
    vim.bo[bufnr].modifiable = true
  end
  pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, { "" })
  if not modifiable then
    vim.bo[bufnr].modifiable = false
  end
end

local function close_task_list_or_window()
  local ok, window = pcall(require, "overseer.window")
  if ok and window.is_open() then
    window.close()
  else
    pcall(vim.cmd.close)
  end
end

local default_keymaps = {
  q = {
    callback = close_task_list_or_window,
    mode = { "n", "t" },
    desc = "Close task list",
  },
  ["<Esc>"] = {
    callback = "<C-\\><C-n>",
    mode = "t",
    desc = "Normal mode",
  },
  ["<C-l>"] = {
    callback = function()
      clear_output_buffer(vim.api.nvim_get_current_buf())
    end,
    mode = { "n", "t" },
    desc = "Clear output",
  },
}

---@param bufnr integer
---@param filetype? string
local function apply_filetype(bufnr, filetype)
  if type(filetype) ~= "string" or filetype == "" then
    return
  end
  if vim.bo[bufnr].filetype == "" then
    vim.bo[bufnr].filetype = filetype
  end
end

---@param task overseer.Task
---@param direction "dock"|"float"|"tab"|"vertical"|"horizontal"
---@param focus boolean
local function open_output(task, direction, focus)
  if direction == "dock" then
    local window = require("overseer.window")
    window.open({
      direction = "bottom",
      enter = focus,
      focus_task_id = task.id,
    })
  else
    local winid = vim.api.nvim_get_current_win()
    ---@cast direction "float"|"tab"|"vertical"|"horizontal"
    task:open_output(direction)
    if not focus then
      vim.api.nvim_set_current_win(winid)
    end
  end
end

---@param task overseer.Task
---@param filetype? string
---@param default_mode? string
---@param keymaps table|false|nil
local function apply_keymaps(task, filetype, default_mode, keymaps)
  local bufnr = task:get_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  apply_filetype(bufnr, filetype)

  if type(keymaps) ~= "table" then
    return
  end

  if vim.b[bufnr].open_output_keymaps_applied == task.id then
    return
  end
  vim.b[bufnr].open_output_keymaps_applied = task.id

  for lhs, rhs_def in pairs(keymaps) do
    if rhs_def ~= false then
      local rhs = rhs_def
      local mode = default_mode or "n"
      local opts = {}

      if type(rhs_def) == "table" then
        opts = vim.deepcopy(rhs_def)
        rhs = opts.callback or opts[1]
        mode = opts.mode or mode
        opts.callback = nil
        opts.mode = nil
        opts[1] = nil
      end

      if rhs ~= nil then
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("keep", opts, { buffer = bufnr, silent = true, nowait = true }))
      end
    end
  end
end

---@type overseer.ComponentFileDefinition
return {
  desc = "Open task output and set keymaps on the output buffer",
  editable = false,
  serializable = false,
  params = {
    on_start = {
      desc = "Open the output when the task starts",
      type = "enum",
      choices = { "always", "never", "if_no_on_output_quickfix" },
      default = "if_no_on_output_quickfix",
      long_desc = "The 'if_no_on_output_quickfix' option will open the task output on start unless the task has the 'on_output_quickfix' component attached.",
    },
    on_complete = {
      desc = "Open the output when the task completes",
      type = "enum",
      choices = { "always", "never", "success", "failure" },
      default = "never",
    },
    on_result = {
      desc = "Open the output when the task produces a result",
      type = "enum",
      choices = { "always", "never", "if_diagnostics" },
      default = "never",
    },
    direction = {
      desc = "Where to open the task output",
      type = "enum",
      choices = { "dock", "float", "tab", "vertical", "horizontal" },
      default = "dock",
      long_desc = "The 'dock' option will open the output docked to the bottom next to the task list.",
    },
    focus = {
      desc = "Focus the output window when it is opened",
      type = "boolean",
      default = false,
    },
    keymap_mode = {
      desc = "Default mode for keymaps",
      type = "string",
      default = "n",
    },
    filetype = {
      desc = "Set filetype for the output buffer",
      type = "string",
      default = "OverseerOutput",
    },
    keymaps = {
      desc = "Keymaps to set on the output buffer",
      type = "opaque",
      optional = true,
    },
  },
  constructor = function(params)
    if params.on_start == true then
      params.on_start = "always"
    elseif params.on_start == false then
      params.on_start = "never"
    end

    ---@type table|false
    local keymaps
    if params.keymaps == nil then
      keymaps = default_keymaps
    elseif params.keymaps == false then
      keymaps = false
    elseif type(params.keymaps) == "table" then
      keymaps = vim.tbl_extend("force", vim.deepcopy(default_keymaps), params.keymaps)
    else
      keymaps = default_keymaps
    end

    local function maybe_apply_keymaps(task)
      apply_keymaps(task, params.filetype, params.keymap_mode, keymaps)
    end

    ---@class OpenOutputKeymapsMethods : overseer.ComponentSkeleton
    ---@field on_bufnr_changed? fun(self: OpenOutputKeymapsMethods, task: overseer.Task, data: any)
    ---@type OpenOutputKeymapsMethods
    local methods = {}

    if params.on_start ~= "never" or keymaps ~= nil then
      methods.on_start = function(_, task)
        maybe_apply_keymaps(task)
        if
          params.on_start == "always"
          or (params.on_start == "if_no_on_output_quickfix" and not task:has_component("on_output_quickfix"))
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    methods.on_output = function(_, task, _)
      maybe_apply_keymaps(task)
    end

    methods.on_bufnr_changed = function(_, task, _)
      maybe_apply_keymaps(task)
    end

    if params.on_result ~= "never" then
      methods.on_result = function(_, task, result)
        maybe_apply_keymaps(task)
        if
          params.on_result == "always"
          or (params.on_result == "if_diagnostics" and not vim.tbl_isempty(result.diagnostics or {}))
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    if params.on_complete ~= "never" then
      methods.on_complete = function(_, task, status, _)
        maybe_apply_keymaps(task)
        if
          params.on_complete == "always"
          or (params.on_complete == "success" and status == STATUS.SUCCESS)
          or (params.on_complete == "failure" and status == STATUS.FAILURE)
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    return methods
  end,
}
