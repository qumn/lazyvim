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

local function guess_short_name(file_path)
  if not file_path or file_path == "" then
    return "java"
  end
  local base = vim.fn.fnamemodify(file_path, ":t:r")
  if base == "" then
    return "java"
  end
  return base
end

local function is_java_filetype(filetype)
  if type(filetype) ~= "string" or filetype == "" then
    return false
  end
  for _, ft in ipairs(vim.split(filetype, ".", { plain = true })) do
    if ft == "java" then
      return true
    end
  end
  return false
end

local function lazyvim_root()
  if _G.LazyVim and _G.LazyVim.root then
    local ok, root = pcall(function()
      return (_G.LazyVim.root.get and _G.LazyVim.root.get()) or _G.LazyVim.root()
    end)
    if ok and type(root) == "string" and root ~= "" then
      return root
    end
  end
end

local function root_has_java_markers(root)
  if type(root) ~= "string" or root == "" then
    return false
  end
  local markers = {
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
    "mvnw",
    "gradlew",
  }
  for _, marker in ipairs(markers) do
    if vim.uv.fs_stat(vim.fs.joinpath(root, marker)) then
      return true
    end
  end
  return false
end

local function should_enable(opts)
  if is_java_filetype(opts.filetype) then
    return true
  end
  local root = lazyvim_root() or opts.dir or vim.fn.getcwd()
  return root_has_java_markers(root)
end

-- because neovim terminal hard wraps lines, so we need to unwrap them manually
local function copy_unwrapped_log_selection()
  -- visual 选区
  local _, ls = unpack(vim.fn.getpos("'<"))
  local _, le = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)

  local function is_new_entry(line)
    return line:match("^%d%d%d%d%-%d%d%-%d%d%s+%d%d:%d%d:%d%d") ~= nil or line:match("^%[%u+%]") ~= nil
  end

  local out = {}
  for _, line in ipairs(lines) do
    if #out == 0 then
      table.insert(out, line)
    else
      if is_new_entry(line) then
        table.insert(out, line)
      else
        out[#out] = out[#out] .. " " .. vim.trim(line)
      end
    end
  end

  local result = table.concat(out, "\n")

  -- 写入剪贴板和匿名寄存器
  vim.fn.setreg("+", result)
  vim.fn.setreg('"', result)

  vim.notify("Unwrapped log copied to clipboard", vim.log.levels.INFO)
end

local function template_defn()
  return {
  name = "Java: Run Main",
  desc = "Build then run main class",
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
      choices = { "always", "never" },
      default = "always",
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
    local current_file = vim.fn.expand("%:p")

    local cwd = params.cwd or guess_cwd(current_file)
    local short = guess_short_name(current_file)

    local build_task = {
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
        { "on_complete_dispose", timeout = 0.5, statuses = { "SUCCESS" } },
        {
          "open_output_keymaps",
          direction = "dock",
          on_start = "always",
          on_complete = "failure",
        },
      },
    }

    local run_task = {
      name = short,
      cmd = "jdtls_run_main",
      cwd = cwd,
      strategy = {
        "user.jdtls_run_main",
        bufnr = bufnr,
        cwd = params.cwd,
        args = params.args,
        vm_args = params.vm_args,
        enable_preview = params.enable_preview,
      },
      components = {
        "force_non_ephemeral",
        { "unique", replace = true },
        "on_complete_notify",
        "on_exit_set_status",
        {
          "open_output_keymaps",
          direction = "dock",
          keymaps = {
            ["gy"] = {
              callback = copy_unwrapped_log_selection,
              mode = "v",
              desc = "Copy unwrapped log (no buffer change)",
            },
          },
        },
      },
    }

    table.insert(build_task.components, { "run_after", tasks = { run_task }, detach = true })

    return build_task
  end,
  }
end

return {
  name = "user.jdtls_run_main",
  generator = function(opts)
    opts = opts or {}
    if not should_enable(opts) then
      return {}
    end
    return { template_defn() }
  end,
}
