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

function JdtlsBuildWorkspace:start(task)
  local hint_bufnr = self.bufnr_hint or vim.api.nvim_get_current_buf()
  local client = find_jdtls_client(hint_bufnr, self.client_id)

  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[self.bufnr].buftype = "nofile"
    vim.bo[self.bufnr].bufhidden = "wipe"
    vim.bo[self.bufnr].swapfile = false
    vim.bo[self.bufnr].modifiable = false
  end

  if not client then
    set_lines(task, self.bufnr, { "jdtls client not found" })
    vim.schedule(function()
      task:on_exit(1)
    end)
    return
  end

  self.client_id = client.id

  local params = self.params or {}
  set_lines(task, self.bufnr, {
    "vscode.java.buildWorkspace",
    ("mainClass: %s"):format(params.mainClass or ""),
    ("projectName: %s"):format(params.projectName or ""),
    ("filePath: %s"):format(params.filePath or ""),
    ("isFullBuild: %s"):format(tostring(params.isFullBuild == true)),
    "",
  })

  if not params.mainClass or params.mainClass == "" then
    append_lines(task, self.bufnr, { "missing mainClass" })
    vim.schedule(function()
      task:on_exit(1)
    end)
    return
  end

  local req = {
    command = "vscode.java.buildWorkspace",
    arguments = { json_encode(params) },
  }

  local ok, request_id = client:request("workspace/executeCommand", req, function(err, result)
    vim.schedule(function()
      if task:is_complete() then
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

      pcall(vim.diagnostic.setqflist, { severity = vim.diagnostic.severity.ERROR, open = false })
      local ok_trouble, trouble = pcall(require, "trouble")
      if ok_trouble then
        pcall(trouble.open, { mode = "qflist", focus = true })
      else
        pcall(vim.cmd, "copen")
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

function JdtlsBuildWorkspace:stop()
  if not self.request_id then
    return
  end

  local client = self.client_id and vim.lsp.get_client_by_id(self.client_id) or nil
  if client and client.cancel_request then
    pcall(function()
      client:cancel_request(self.request_id)
    end)
  end

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
