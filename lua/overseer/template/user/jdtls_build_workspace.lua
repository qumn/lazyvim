local overseer = require("overseer")

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
    local current_file = vim.fn.expand("%:p")

    local cwd = params.cwd or guess_cwd(current_file)

    return {
      name = "buildWorkspace",
      cmd = "jdtls_build_workspace",
      cwd = cwd,
      strategy = {
        "user.jdtls_build_workspace",
        bufnr = bufnr,
        continue_on_error = params.continue_on_error,
        open_qf_on_error = params.open_qf_on_error,
        params = {
          filePath = current_file ~= "" and current_file or nil,
          isFullBuild = params.full_build,
        },
      },
      components = {
        "on_complete_notify",
        "on_exit_set_status",
        { "open_output", direction = "dock", on_start = "always", on_complete = "failure" },
      },
    }
  end,
  condition = {
    filetype = { "java" },
  },
}
