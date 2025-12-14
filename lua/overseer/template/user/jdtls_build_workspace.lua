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

return {
  name = "Java: Build",
  desc = "Build current project",
  tags = { overseer.TAG.BUILD },
  params = {
    full_build = {
      desc = "Set isFullBuild=true",
      type = "boolean",
      default = false,
    },
    continue_on_error = {
      desc = "Behavior when build has errors",
      type = "enum",
      choices = { "always", "never" },
      default = "always",
    },
    open_qf_on_error = {
      desc = "Open quickfix on build error",
      type = "boolean",
      default = true,
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
        name = "jdtls buildWorkspace (no jdtls)",
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
        name = "jdtls buildWorkspace (canceled)",
        cmd = { "bash", "-lc", "echo 'canceled'; exit 1" },
        components = { "default" },
      }
    end

    local cwd = params.cwd or guess_cwd(pick.filePath)
    local short = pick.mainClass:match("([^.]+)$") or pick.mainClass

    return {
      name = string.format("jdtls build %s", short),
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
  end,
  condition = {
    filetype = { "java" },
  },
}
