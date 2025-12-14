local util = require("overseer.util")

local JdtlsBuildWorkspace = {}

local function list_clients()
  if vim.lsp.get_clients then
    return vim.lsp.get_clients()
  end
  return vim.lsp.get_active_clients()
end

local function find_jdtls_client(bufnr, preferred_id)
  if preferred_id then
    local c = vim.lsp.get_client_by_id(preferred_id)
    if c then
      return c
    end
  end

  if bufnr and bufnr > 0 then
    for _, c in ipairs(list_clients()) do
      if c.name == "jdtls" and c.attached_buffers and c.attached_buffers[bufnr] then
        return c
      end
    end
  end

  for _, c in ipairs(list_clients()) do
    if c.name == "jdtls" then
      return c
    end
  end

  return nil
end

local function json_encode(obj)
  if vim.json and vim.json.encode then
    return vim.json.encode(obj)
  end
  return vim.fn.json_encode(obj)
end

local function set_lines(task, bufnr, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  if task and not task:is_complete() then
    task:dispatch("on_output", lines)
    task:dispatch("on_output_lines", lines)
  end
end

local function append_lines(task, bufnr, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.bo[bufnr].modifiable = true
  local count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, count, count, true, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  if task and not task:is_complete() then
    task:dispatch("on_output", lines)
    task:dispatch("on_output_lines", lines)
  end
end

local function format_main_class_item(opt, supports_chunks)
  local full = opt.mainClass or ""
  local short = full:match("([^.]+)$") or full
  local project = opt.projectName or ""
  local file_path = opt.filePath and opt.filePath ~= "" and vim.fn.fnamemodify(opt.filePath, ":~:.") or ""

  if supports_chunks then
    local chunks = { { short, "Type" } }
    if project ~= "" then
      table.insert(chunks, { " [" .. project .. "]", "SnacksPickerSpecial" })
    end
    if file_path ~= "" then
      table.insert(chunks, { " - " .. file_path, "Comment" })
    end
    return chunks
  end

  local label = short
  if project ~= "" then
    label = label .. " [" .. project .. "]"
  end
  if file_path ~= "" then
    label = label .. " - " .. file_path
  end
  return label
end

local function pick_main_class(options, current_file, cb)
  local candidates = {}
  for _, opt in ipairs(options or {}) do
    if current_file and opt.filePath == current_file then
      table.insert(candidates, opt)
    end
  end
  if #candidates == 0 then
    candidates = options or {}
  end

  if #candidates == 0 then
    cb(nil)
    return
  end

  if #candidates == 1 then
    cb(candidates[1])
    return
  end

  local done = false
  local function finish(item)
    if done then
      return
    end
    done = true
    cb(item)
  end

  local ok_snacks = pcall(require, "snacks")
  if ok_snacks then
    local ok_select, select = pcall(require, "snacks.picker.select")
    if ok_select and select and type(select.select) == "function" then
      select.select(candidates, {
        prompt = "Select main class",
        format_item = format_main_class_item,
      }, function(item)
        finish(item)
      end)
      return
    end
  end

  local ok_telescope, pickers = pcall(require, "telescope.pickers")
  if ok_telescope then
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
      prompt_title = "Select main class",
      finder = finders.new_table({
        results = candidates,
        entry_maker = function(item)
          local display = format_main_class_item(item)
          return {
            value = item,
            display = display,
            ordinal = display,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          finish(selection and selection.value or nil)
          actions.close(prompt_bufnr)
        end)
        actions.close:enhance({
          post = function()
            finish(nil)
          end,
        })
        return true
      end,
    }):find()
    return
  end

  vim.ui.select(candidates, {
    prompt = "Select main class",
    format_item = format_main_class_item,
  }, function(item)
    finish(item)
  end)
end

local function cancel_request(client_id, request_id)
  if not request_id then
    return
  end
  local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
  if client and client.cancel_request then
    pcall(function()
      client:cancel_request(request_id)
    end)
  end
end

function JdtlsBuildWorkspace.new(opts)
  opts = opts or {}
  local strategy = {
    bufnr = nil,
    request_id = nil,
    client_id = opts.client_id,
    bufnr_hint = opts.bufnr,
    params = opts.params or {},
    continue_on_error = opts.continue_on_error or "always",
    open_qf_on_error = opts.open_qf_on_error ~= false,
    wait_timeout_ms = opts.wait_timeout_ms or 30000,
    _stopped = false,
  }
  setmetatable(strategy, { __index = JdtlsBuildWorkspace })
  return strategy
end

function JdtlsBuildWorkspace:reset()
  self:stop()
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    util.soft_delete_buf(self.bufnr)
  end
  self.bufnr = nil
end

function JdtlsBuildWorkspace:get_bufnr()
  return self.bufnr
end

local function open_diagnostics_qf()
  pcall(vim.diagnostic.setqflist, { severity = vim.diagnostic.severity.ERROR, open = false })
  local ok_trouble, trouble = pcall(require, "trouble")
  if ok_trouble then
    pcall(trouble.open, { mode = "qflist", focus = false })
  else
    pcall(vim.cmd, "copen")
  end
end

local function propagate_main_to_run_after(task, pick)
  if not pick or type(pick) ~= "table" then
    return
  end
  if not pick.mainClass or pick.mainClass == "" then
    return
  end
  if not task or type(task.components) ~= "table" then
    return
  end

  local short = pick.mainClass:match("([^.]+)$") or pick.mainClass

  for _, comp in ipairs(task.components) do
    if comp.name == "run_after" and comp.params then
      local tasks = comp.params.tasks or comp.params.task_names
      if type(tasks) == "table" then
        for _, defn in ipairs(tasks) do
          if type(defn) == "table" and defn[1] == nil then
            local strategy = defn.strategy
            if type(strategy) == "table" and strategy[1] == "user.jdtls_run_main" then
              strategy.main = vim.deepcopy(pick)
              if short and short ~= "" then
                defn.name = short
              end
            end
          end
        end
      end
    end
  end
end

function JdtlsBuildWorkspace:_run_build(task, client, hint_bufnr)
  local params = self.params or {}

  propagate_main_to_run_after(task, params)

  set_lines(task, self.bufnr, {
    "vscode.java.buildWorkspace",
    ("mainClass: %s"):format(params.mainClass or ""),
    ("projectName: %s"):format(params.projectName or ""),
    ("filePath: %s"):format(params.filePath or ""),
    ("isFullBuild: %s"):format(tostring(params.isFullBuild == true)),
    "",
  })

  local req = {
    command = "vscode.java.buildWorkspace",
    arguments = { json_encode(params) },
  }

  local ok, request_id = client:request("workspace/executeCommand", req, function(err, result)
    vim.schedule(function()
      self.request_id = nil

      if task:is_complete() or self._stopped then
        return
      end

      if err then
        append_lines(task, self.bufnr, { "error: " .. (err.message or vim.inspect(err)) })
        task:on_exit(1)
        return
      end

      local status = tonumber(result) or result
      append_lines(task, self.bufnr, { "status: " .. tostring(status) })

      if status == 1 then
        task:on_exit(0)
        return
      end

      if status == 3 then
        task:stop()
        return
      end

      if self.open_qf_on_error and (status == 0 or status == 100) then
        open_diagnostics_qf()
      end

      if self.continue_on_error == "never" then
        task:on_exit(1)
      else
        task:on_exit(0)
      end
    end)
  end, hint_bufnr)

  if not ok then
    append_lines(task, self.bufnr, { "failed to send LSP request" })
    vim.schedule(function()
      task:on_exit(1)
    end)
    return
  end

  self.request_id = request_id
end

function JdtlsBuildWorkspace:_ensure_main_class(task, client, hint_bufnr)
  local params = self.params or {}

  local file_path = params.filePath
  if not file_path or file_path == "" then
    local bufname = vim.api.nvim_buf_get_name(hint_bufnr)
    if bufname ~= "" then
      file_path = bufname
      params.filePath = bufname
      self.params = params
    end
  end

  if params.mainClass and params.mainClass ~= "" then
    self:_run_build(task, client, hint_bufnr)
    return
  end

  append_lines(task, self.bufnr, { "vscode.java.resolveMainClass" })

  local ok, request_id = client:request(
    "workspace/executeCommand",
    { command = "vscode.java.resolveMainClass", arguments = {} },
    function(err, result)
      vim.schedule(function()
        self.request_id = nil

        if task:is_complete() or self._stopped then
          return
        end

        if err or type(result) ~= "table" then
          append_lines(task, self.bufnr, { "resolveMainClass failed" })
          task:on_exit(1)
          return
        end

        pick_main_class(result, file_path, function(pick)
          if task:is_complete() or self._stopped then
            return
          end

          if not pick or not pick.mainClass then
            append_lines(task, self.bufnr, { "canceled" })
            task:stop()
            return
          end

          params.mainClass = pick.mainClass
          params.projectName = pick.projectName
          params.filePath = pick.filePath or params.filePath
          self.params = params

          self:_run_build(task, client, hint_bufnr)
        end)
      end)
    end,
    hint_bufnr
  )

  if not ok then
    append_lines(task, self.bufnr, { "failed to send resolveMainClass" })
    vim.schedule(function()
      task:on_exit(1)
    end)
    return
  end

  self.request_id = request_id
end

function JdtlsBuildWorkspace:start(task)
  self._stopped = false

  local hint_bufnr = self.bufnr_hint or vim.api.nvim_get_current_buf()

  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[self.bufnr].buftype = "nofile"
    vim.bo[self.bufnr].bufhidden = "wipe"
    vim.bo[self.bufnr].swapfile = false
    vim.bo[self.bufnr].modifiable = false
  end

  set_lines(task, self.bufnr, { "vscode.java.buildWorkspace", "waiting for jdtls...", "" })

  local started_at = vim.uv.hrtime()

  local function tick()
    if task:is_complete() or self._stopped then
      return
    end

    local client = find_jdtls_client(hint_bufnr, self.client_id)
    if client and client.initialized ~= false then
      self.client_id = client.id
      self:_ensure_main_class(task, client, hint_bufnr)
      return
    end

    local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
    if elapsed_ms > self.wait_timeout_ms then
      append_lines(task, self.bufnr, { "jdtls client not found" })
      task:on_exit(1)
      return
    end

    vim.defer_fn(tick, 200)
  end

  tick()
end

function JdtlsBuildWorkspace:stop()
  self._stopped = true
  cancel_request(self.client_id, self.request_id)
  self.request_id = nil
end

function JdtlsBuildWorkspace:dispose()
  self:stop()
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    util.soft_delete_buf(self.bufnr)
  end
  self.bufnr = nil
end

return JdtlsBuildWorkspace
