local util = require("overseer.util")
local jdtls_bootstrap = require("overseer.strategy.user.jdtls_bootstrap")

local JdtlsRunMain = {}

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

local function guess_cwd(file_path)
  if not file_path or file_path == "" then
    return vim.fn.getcwd()
  end
  local start = vim.fs.dirname(file_path)
  local markers = {
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
    "mvnw",
    "gradlew",
    ".git",
  }
  local found = vim.fs.find(markers, { upward = true, path = start })[1]
  if found then
    return vim.fs.dirname(found)
  end
  return start
end

local function path_sep()
  if vim.fn.has("win32") == 1 then
    return ";"
  end
  return ":"
end

local function as_list(v)
  if type(v) == "table" then
    return v
  end
  return {}
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

    pickers
      .new({}, {
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
      })
      :find()
    return
  end

  vim.ui.select(candidates, {
    prompt = "Select main class",
    format_item = format_main_class_item,
  }, function(item)
    finish(item)
  end)
end

function JdtlsRunMain.new(opts)
  opts = opts or {}
  local strategy = {
    bufnr = nil,
    client_id = opts.client_id,
    bufnr_hint = opts.bufnr,
    cwd = opts.cwd,
    main = opts.main,
    args = opts.args or {},
    vm_args = opts.vm_args or {},
    enable_preview = opts.enable_preview or false,
    wait_timeout_ms = opts.wait_timeout_ms or 30000,
    request_id = nil,
    inner = nil,
    _stopped = false,
  }
  setmetatable(strategy, { __index = JdtlsRunMain })
  return strategy
end

function JdtlsRunMain:reset()
  self:stop()
  if self.inner and self.inner.reset then
    self.inner:reset()
  end
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    util.soft_delete_buf(self.bufnr)
  end
  self.bufnr = nil
  self.inner = nil
end

function JdtlsRunMain:get_bufnr()
  if self.inner and self.inner.get_bufnr then
    local bufnr = self.inner:get_bufnr()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      return bufnr
    end
  end
  return self.bufnr
end

local function wait_for_client(self, task, hint_bufnr, cb)
  local started_at = vim.uv.hrtime()
  local root_dir = task and task.cwd or self.cwd

  local function tick()
    if self._stopped or task:is_complete() then
      return
    end

    local client = jdtls_bootstrap.find_jdtls_client(hint_bufnr, self.client_id, root_dir)
    if client and client.initialized ~= false then
      self.client_id = client.id
      cb(client)
      return
    end

    local elapsed_ms = (vim.uv.hrtime() - started_at) / 1e6
    if elapsed_ms > self.wait_timeout_ms then
      local lines = { "timed out waiting for jdtls" }
      local clients = vim.lsp.get_clients and vim.lsp.get_clients() or {}
      for _, c in ipairs(clients or {}) do
        if c and c.name then
          local rd = (c.config and c.config.root_dir) or c.root_dir or ""
          table.insert(lines, ("- %s (id=%s) root=%s"):format(c.name, tostring(c.id), tostring(rd)))
        end
      end
      append_lines(task, self.bufnr, lines)
      task:on_exit(1)
      return
    end

    vim.defer_fn(tick, 200)
  end

  jdtls_bootstrap.ensure_jdtls_started({ root_dir = root_dir, bufnr = hint_bufnr, client_id = self.client_id })
  tick()
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

function JdtlsRunMain:start(task)
  self._stopped = false

  local hint_bufnr = self.bufnr_hint or vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(hint_bufnr)

  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)
    vim.bo[self.bufnr].buftype = "nofile"
    vim.bo[self.bufnr].bufhidden = "wipe"
    vim.bo[self.bufnr].swapfile = false
    vim.bo[self.bufnr].modifiable = false
  end

  set_lines(task, self.bufnr, {
    "jdtls run main",
    "waiting for jdtls...",
    "",
  })

  wait_for_client(self, task, hint_bufnr, function(client)
    if task:is_complete() or self._stopped then
      return
    end

    self.client_id = client.id
    local req_bufnr = jdtls_bootstrap.pick_request_bufnr(client, hint_bufnr)

    local function continue_with_pick(pick)
      if task:is_complete() or self._stopped then
        return
      end

      if not pick or not pick.mainClass then
        append_lines(task, self.bufnr, { "canceled" })
        task:stop()
        return
      end

      local short = pick.mainClass:match("([^.]+)$") or pick.mainClass
      if short and short ~= "" then
        task.name = short
        pcall(function()
          require("overseer.task_list").touch(task)
        end)
      end

      local cwd = self.cwd or guess_cwd(pick.filePath)
      task.cwd = cwd

      append_lines(task, self.bufnr, { "vscode.java.resolveClasspath" })
      local ok_cp, cp_id = client:request(
        "workspace/executeCommand",
        { command = "vscode.java.resolveClasspath", arguments = { pick.mainClass, pick.projectName } },
        function(cp_err, cp)
          vim.schedule(function()
            self.request_id = nil

            if task:is_complete() or self._stopped then
              return
            end

            if cp_err or type(cp) ~= "table" then
              append_lines(task, self.bufnr, { "resolveClasspath failed" })
              task:on_exit(1)
              return
            end

            append_lines(task, self.bufnr, { "vscode.java.resolveJavaExecutable" })
            local ok_java, java_id = client:request("workspace/executeCommand", {
              command = "vscode.java.resolveJavaExecutable",
              arguments = { pick.mainClass, pick.projectName },
            }, function(java_err, java_exec)
              vim.schedule(function()
                self.request_id = nil

                if task:is_complete() or self._stopped then
                  return
                end

                if java_err or not java_exec or java_exec == "" then
                  java_exec = vim.fn.exepath("java")
                  if java_exec == "" then
                    java_exec = "java"
                  end
                end

                local module_paths = as_list(cp[1] or cp[0])
                local class_paths = as_list(cp[2] or cp[1])

                local cmd = { java_exec }
                for _, a in ipairs(self.vm_args or {}) do
                  table.insert(cmd, a)
                end
                if self.enable_preview then
                  table.insert(cmd, "--enable-preview")
                end

                local sep = path_sep()
                if #module_paths > 0 then
                  table.insert(cmd, "--module-path")
                  table.insert(cmd, table.concat(module_paths, sep))
                end
                if #class_paths > 0 then
                  table.insert(cmd, "-cp")
                  table.insert(cmd, table.concat(class_paths, sep))
                end

                table.insert(cmd, pick.mainClass)
                for _, a in ipairs(self.args or {}) do
                  table.insert(cmd, a)
                end

                local cfg = require("overseer.config")
                local jobstart = require("overseer.strategy.jobstart")
              self.inner = jobstart.new({
                use_terminal = cfg.output.use_terminal,
                preserve_output = cfg.output.preserve_output,
              })

                local prev_bufnr = self.bufnr
                task.cmd = cmd
                self.inner:start(task)

                local next_bufnr = self.inner:get_bufnr()
                if prev_bufnr and next_bufnr and prev_bufnr ~= next_bufnr then
                  vim.b[next_bufnr].overseer_task = task.id
                  vim.bo[next_bufnr].buflisted = false
                  util.replace_buffer_in_wins(prev_bufnr, next_bufnr)
                  if vim.api.nvim_buf_is_valid(prev_bufnr) then
                    util.soft_delete_buf(prev_bufnr)
                  end
                end
                if next_bufnr and vim.api.nvim_buf_is_valid(next_bufnr) then
                  task:dispatch("on_bufnr_changed", { prev = prev_bufnr, next = next_bufnr })
                end
                self.bufnr = nil
              end)
            end, req_bufnr)

            if ok_java then
              self.request_id = java_id
            else
              append_lines(task, self.bufnr, { "failed to send resolveJavaExecutable" })
              task:on_exit(1)
            end
          end)
        end,
        req_bufnr
      )

      if ok_cp then
        self.request_id = cp_id
      else
        append_lines(task, self.bufnr, { "failed to send resolveClasspath" })
        task:on_exit(1)
      end
    end

    if self.main and type(self.main) == "table" and self.main.mainClass and self.main.mainClass ~= "" then
      continue_with_pick(self.main)
      return
    end

    append_lines(task, self.bufnr, { "vscode.java.resolveMainClass" })

    local ok, req_id = client:request(
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

          pick_main_class(result, file_path ~= "" and file_path or nil, function(pick)
            continue_with_pick(pick)
          end)
        end)
      end,
      req_bufnr
    )

    if ok then
      self.request_id = req_id
    else
      append_lines(task, self.bufnr, { "failed to send resolveMainClass" })
      task:on_exit(1)
    end
  end)
end

function JdtlsRunMain:stop()
  self._stopped = true
  cancel_request(self.client_id, self.request_id)
  self.request_id = nil
  if self.inner and self.inner.stop then
    self.inner:stop()
  end
end

function JdtlsRunMain:dispose()
  self:stop()
  if self.inner and self.inner.dispose then
    self.inner:dispose()
  end
  self.inner = nil
  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    util.soft_delete_buf(self.bufnr)
  end
  self.bufnr = nil
end

return JdtlsRunMain
