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
      table.insert(cmd, "-Xmx4G")
      -- table.insert(cmd, "--jvm-arg=-Djava.import.generatesMetadataFilesAtProjectRoot=false")
      -- table.insert(cmd, "-Dlog.perf.level=OFF")
      -- local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
      -- local data_dir = vim.fn.stdpath("cache") .. "jdtls/" .. project_name

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
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "java", "xml" },
        callback = function(args)
          local mybatis = require("mybatis")
          if not mybatis.is_mapper_file(args.buf) then
            return
          end

          vim.keymap.set("n", "gd", function()
            mybatis.jump_or_fallback()
          end, { buffer = args.buf, desc = "MyBatis jump or definition" })
        end,
      })
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

  {
    "mistweaverco/kulala.nvim",
    keys = {
      { "<leader>Rs", desc = "Send request" },
      { "<leader>Ra", desc = "Send all requests" },
      { "<leader>Rb", desc = "Open scratchpad" },
    },
    ft = { "http", "rest" },
    opts = {
      global_keymaps = true,
      global_keymaps_prefix = "<leader>R",
      kulala_keymaps_prefix = "",
    },
  },
}
