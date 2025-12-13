-- ---------- helpers ----------
local function is_macos()
  ---@diagnostic disable-next-line: undefined-field
  return vim.g.os_name == "Darwin"
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function java_home(version)
  local uname = vim.g.os_name

  -- macOS: /usr/libexec/java_home -v <version>
  if uname == "Darwin" then
    local out = vim.fn.system(("/usr/libexec/java_home -v%s"):format(version))
    return trim(out)
  end

  -- Linux
  if uname == "Linux" then
    -- Arch Linux: archlinux-java exists
    if vim.fn.executable("archlinux-java") then
      local candidates = {
        "java-" .. version .. "-openjdk",
        "java-" .. version,
      }

      for _, name in ipairs(candidates) do
        local ok = vim.fn.system(("archlinux-java get %s"):format(name))
        if ok:match("/") then
          return "/usr/lib/jvm/" .. name
        end
      end
    end

    -- Generic Linux fallback
    local java = vim.fn.exepath("java")
    if java ~= "" then
      return java:gsub("/bin/java$", "")
    end
  end

  return nil
end

local function is_mybatis_mapper_file(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  return name:match("Mapper%.java$") or name:match("Mapper%.xml$")
end

return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- jdtls cmd flags
      local cmd = opts.cmd
      table.insert(cmd, "--jvm-arg=-Djava.import.generatesMetadataFilesAtProjectRoot=false")
      table.insert(cmd, "-Dlog.perf.level=OFF")

      -- macOS: pin the java executable used to run jdtls (JDK 21)
      if is_macos() then
        local j21 = java_home("21")
        table.insert(cmd, "--java-executable=" .. j21 .. "/bin/java")
      end

      -- jdtls settings
      local extra = {
        settings = {
          java = {
            configuration = {
              runtimes = {
                { name = "jdk8", path = java_home("1.8") },
                { name = "jdk17", path = java_home("17") },
                { name = "jdk21", path = java_home("21") },
              },
            },
          },
        },
      }

      return vim.tbl_deep_extend("force", opts, extra)
    end,
  },

  {
    dir = vim.fn.stdpath("config") .. "/spring.nvim",
    name = "spring.nvim",
    cmd = "SpringEndpoints",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
      { "<Leader>sr", mode = "n", "<cmd>SpringEndpoints<cr>", desc = "List Spring Endpoints" },
    },
    config = function()
      require("spring").setup()
      require("telescope").load_extension("spring")
    end,
  },

  {
    dir = "/home/qumn/Workspace/mybatis.nvim",
    dev = true,
    ft = { "java", "xml" },
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
      require("mybatis").setup({})
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local builtin = require("telescope.builtin")
      local orig = builtin.lsp_definitions

      -- enhance 'lsp_definitions' to support mybatis mapper files
      builtin.lsp_definitions = function(o)
        local buf = vim.api.nvim_get_current_buf()

        if is_mybatis_mapper_file(buf) then
          local mybatis = package.loaded["mybatis"]
          local jump = mybatis and mybatis.jump_or_fallback
          if type(jump) == "function" then
            return jump()
          end
        end

        return orig(o)
      end

      return opts
    end,
  },
}
