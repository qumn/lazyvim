local overseer = require("overseer")

local function list_clients()
  if vim.lsp.get_clients then
    return vim.lsp.get_clients()
  end
  return vim.lsp.get_active_clients()
end

local function find_jdtls_client(bufnr)
  for _, c in ipairs(list_clients()) do
    if c.name == "jdtls" and c.attached_buffers and c.attached_buffers[bufnr] then
      return c
    end
  end
  for _, c in ipairs(list_clients()) do
    if c.name == "jdtls" then
      return c
    end
  end
  return nil
end

local function exec_sync(client, bufnr, command, arguments, timeout_ms)
  local resp = client:request_sync(
    "workspace/executeCommand",
    { command = command, arguments = arguments or {} },
    timeout_ms or 60000,
    bufnr
  )
  if not resp then
    return nil, "timeout"
  end
  if resp.err then
    return nil, resp.err
  end
  return resp.result, nil
end

local function pick_main_class(options, current_file)
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
    return nil
  end

  if #candidates == 1 then
    return candidates[1]
  end

  local items = { "Select main class:" }
  for i, opt in ipairs(candidates) do
    local label = opt.mainClass or ""
    if opt.projectName and opt.projectName ~= "" then
      label = label .. " [" .. opt.projectName .. "]"
    end
    if opt.filePath and opt.filePath ~= "" then
      label = label .. " - " .. vim.fn.fnamemodify(opt.filePath, ":~:.")
    end
    table.insert(items, string.format("%d. %s", i, label))
  end
  local idx = vim.fn.inputlist(items)
  if idx < 1 or idx > #candidates then
    return nil
  end
  return candidates[idx]
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

local function build_java_cmd(client, bufnr, pick, params)
  local cp, err = exec_sync(client, bufnr, "vscode.java.resolveClasspath", { pick.mainClass, pick.projectName }, 60000)
  if err or type(cp) ~= "table" then
    return nil, "resolveClasspath failed"
  end

  local module_paths = as_list(cp[1] or cp[0])
  local class_paths = as_list(cp[2] or cp[1])

  local java_exec, jerr = exec_sync(client, bufnr, "vscode.java.resolveJavaExecutable", { pick.mainClass, pick.projectName }, 60000)
  if jerr or not java_exec or java_exec == "" then
    java_exec = vim.fn.exepath("java")
    if java_exec == "" then
      java_exec = "java"
    end
  end

  local cmd = { java_exec }
  for _, a in ipairs(params.vm_args or {}) do
    table.insert(cmd, a)
  end

  if params.enable_preview then
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
  for _, a in ipairs(params.args or {}) do
    table.insert(cmd, a)
  end

  return cmd, nil
end

return {
  name = "jdtls run main (buildWorkspace)",
  desc = "buildWorkspace -> resolveClasspath -> run",
  tags = { overseer.TAG.RUN },
  params = {
    full_build = {
      desc = "Set isFullBuild=true",
      type = "boolean",
      default = false,
    },
    continue_on_error = {
      desc = "Behavior when build has errors",
      type = "enum",
      choices = { "prompt", "always", "never" },
      default = "prompt",
    },
    open_qf_on_error = {
      desc = "Open quickfix on build error",
      type = "boolean",
      default = true,
    },
    args = {
      desc = "Program args",
      type = "list",
      subtype = { type = "string" },
      delimiter = " ",
      default = {},
    },
    vm_args = {
      desc = "VM args",
      type = "list",
      subtype = { type = "string" },
      delimiter = " ",
      default = {},
    },
    enable_preview = {
      desc = "Add --enable-preview",
      type = "boolean",
      default = false,
    },
    cwd = {
      desc = "Working directory (optional)",
      type = "string",
      optional = true,
    },
  },
  builder = function(params)
    local bufnr = vim.api.nvim_get_current_buf()
    local client = find_jdtls_client(bufnr)
    if not client then
      return {
        name = "jdtls run (no jdtls)",
        cmd = { "bash", "-lc", "echo 'jdtls client not found'; exit 1" },
        components = { "default" },
      }
    end

    local mains, err = exec_sync(client, bufnr, "vscode.java.resolveMainClass", {}, 60000)
    if err or type(mains) ~= "table" then
      return {
        name = "jdtls resolveMainClass failed",
        cmd = { "bash", "-lc", "echo 'resolveMainClass failed'; exit 1" },
        components = { "default" },
      }
    end

    local current_file = vim.fn.expand("%:p")
    local pick = pick_main_class(mains, current_file)
    if not pick or not pick.mainClass then
      return {
        name = "jdtls run (canceled)",
        cmd = { "bash", "-lc", "echo 'canceled'; exit 1" },
        components = { "default" },
      }
    end

    local cwd = params.cwd or guess_cwd(pick.filePath)
    local short = pick.mainClass:match("([^.]+)$") or pick.mainClass

    local java_cmd, jerr = build_java_cmd(client, bufnr, pick, params)
    if jerr or not java_cmd then
      return {
        name = string.format("jdtls run %s (classpath failed)", short),
        cmd = { "bash", "-lc", "echo 'resolveClasspath/resolveJavaExecutable failed'; exit 1" },
        components = { "default" },
      }
    end

    local build_task = {
      name = "buildWorkspace",
      cmd = "jdtls_build_workspace",
      cwd = cwd,
      strategy = {
        "user.jdtls_build_workspace",
        bufnr = bufnr,
        client_id = client.id,
        continue_on_error = params.continue_on_error,
        open_qf_on_error = params.open_qf_on_error,
        params = {
          mainClass = pick.mainClass,
          projectName = pick.projectName,
          filePath = pick.filePath,
          isFullBuild = params.full_build,
        },
      },
      components = {
        "on_complete_notify",
        "on_exit_set_status",
        { "open_output", direction = "dock" },
      },
    }

    local run_task = {
      name = string.format("run %s", short),
      cmd = java_cmd,
      cwd = cwd,
      components = {
        "on_complete_notify",
        "on_exit_set_status",
        { "open_output", direction = "dock" },
      },
    }

    return {
      name = string.format("jdtls build+run %s", short),
      cmd = "jdtls_build_and_run",
      cwd = cwd,
      strategy = {
        "orchestrator",
        tasks = { build_task, run_task },
      },
      components = { "default" },
    }
  end,
  condition = {
    filetype = { "java" },
  },
}
