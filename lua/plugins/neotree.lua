return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      group_empty_dirs = true,
      scan_mode = "deep",
    },
    window = {
      mappings = {
        ["i"] = "noop",
        ["o"] = {
          "open",
          nowait = true,
        },
        ["oc"] = "noop",
        ["od"] = "noop",
        ["og"] = "noop",
        ["om"] = "noop",
        ["on"] = "noop",
        ["os"] = "noop",
        ["ot"] = "noop",
        ["l"] = "noop",
        ["lf"] = "system_explorer",
      },
    },
    commands = {
      system_explorer = function(state)
        local node = state.tree:get_node()
        local path = node:get_id()
        local uname = vim.loop.os_uname()

        if uname.sysname == "Darwin" then
          -- macOs: open file in default application in the background.
          vim.fn.jobstart({ "open", "-R", path }, { detach = true })
        elseif uname.sysname == "Linux" then
          -- Linux: open file in default application
          vim.fn.jobstart({ "xdg-open", path }, { detach = true })
        elseif uname.sysname == "Windows" then
          -- Windows: Without removing the file from the path, it opens in code.exe instead of explorer.exe
          local p
          local lastSlashIndex = path:match("^.+()\\[^\\]*$") -- Match the last slash and everything before it
          if lastSlashIndex then
            p = path:sub(1, lastSlashIndex - 1) -- Extract substring before the last slash
          else
            p = path -- If no slash found, return original path
          end
          vim.cmd("silent !start explorer " .. p)
        end
      end,
    },
  },
  -- keys = {
  --   {
  --     "-",
  --     mode = { "n" },
  --     function()
  --       local reveal_file = vim.fn.expand("%:p")
  --       if reveal_file == "" then
  --         reveal_file = vim.fn.getcwd()
  --       else
  --         local f = io.open(reveal_file, "r")
  --         if f then
  --           f.close(f)
  --         else
  --           reveal_file = vim.fn.getcwd()
  --         end
  --       end
  --
  --       local roots = LazyVim.root.detect({ all = true })
  --       roots = vim
  --         .iter(roots)
  --         :map(function(r)
  --           return r.paths or {}
  --         end)
  --         :flatten()
  --         :totable()
  --       -- Sort roots so that those prefixed by `reveal_file` come first.
  --       -- Among those, shorter paths are prioritized.
  --       table.sort(roots, function(a, b)
  --         local a_match = vim.startswith(reveal_file, a)
  --         local b_match = vim.startswith(reveal_file, b)
  --
  --         if a_match ~= b_match then
  --           return a_match
  --         end
  --
  --         return #a < #b
  --       end)
  --       local dir_root = roots[1] or LazyVim.root.cwd()
  --
  --       require("neo-tree.command").execute({
  --         action = "focus",
  --         dir = dir_root,
  --         reveal_file = reveal_file, -- path to file or folder to reveal
  --         reveal_force_cwd = true, -- change cwd without asking if needed
  --       })
  --     end,
  --     desc = "Open neo-tree at current file or working directory",
  --   },
  -- },
}
