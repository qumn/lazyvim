return {
  {
    "lewis6991/gitsigns.nvim",
    event = "LazyFile",
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
        delay = 200,
        ignore_whitespace = false,
        virt_text_priority = 100,
        use_focus = true,
      },
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

      -- stylua: ignore start
      map("n", "]h", function() gs.nav_hunk("next") end, "Next Hunk")
      map("n", "[h", function() gs.nav_hunk("prev") end, "Prev Hunk")
      map("n", "]H", function() gs.nav_hunk("last") end, "Last Hunk")
      map("n", "[H", function() gs.nav_hunk("first") end, "First Hunk")
      map({ "n", "v" }, "<leader>ghs", ":Gitsigns stage_hunk<CR>", "Stage Hunk")
      map({ "n", "v" }, "<leader>ghr", ":Gitsigns reset_hunk<CR>", "Reset Hunk")
      map("n", "<leader>ghS", gs.stage_buffer, "Stage Buffer")
      map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo Stage Hunk")
      map("n", "<leader>ghR", gs.reset_buffer, "Reset Buffer")
      map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview Hunk Inline")
      map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame Line")
      map("n", "<leader>ghd", gs.diffthis, "Diff This")
      map("n", "<leader>ghD", function() gs.diffthis("~") end, "Diff This ~")
        -- map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "GitSigns Select Hunk")
        -- stylua: ignore end
      end,
    },
  },

  -- code diff
  {
    "esmuellert/vscode-diff.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    cmd = "CodeDiff",
    enabled = false,
    opts = {
      -- Keymaps in diff view
      keymaps = {
        view = {
          quit = "q",
          toggle_explorer = "<leader>e",
          next_hunk = "N", -- Jump to next change
          prev_hunk = "I", -- Jump to previous change
          next_file = "<Down>", -- Next file in explorer mode
          prev_file = "<Up>", -- Previous file in explorer mode
        },
        explorer = {
          select = "o", -- Open diff for selected file
          hover = "I", -- Show file diff preview
          refresh = "R", -- Refresh git status
        },
      },
    },
    keys = {
      { "<Leader>gd", mode = "n", "<CMD>CodeDiff<CR>", desc = "Open CodeDiff" },
      { "<Leader>gf", mode = "n", "<CMD>CodeDiff file HEAD<CR>", desc = "CodeDiff Current Buffer" },
    },
  },
  {
    "NeogitOrg/neogit",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
    },
    opts = {
      mappings = {
        status = {
          ["n"] = "MoveDown",
          ["i"] = "MoveUp",
          ["o"] = "Toggle",
          ["l"] = "OpenTree",
        },
        popup = {
          ["n"] = false,
          ["i"] = false,
          ["r"] = "IgnorePopup",
          ["k"] = "RebasePopup",
        },
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewLog",
    },
    keys = {
      { "<Leader>gd", mode = "n", "<CMD>DiffviewOpen<CR>", desc = "Open Diffview" },
      { "<Leader>gf", mode = "n", "<CMD>DiffviewFileHistory %<CR>", desc = "Diffview Current Buffer" },
    },
    opts = function()
      local actions = require("diffview.actions")
      local lib = require("diffview.lib")
      local DiffView = require("diffview.scene.views.diff.diff_view").DiffView

      local function smart_next()
        local before = vim.api.nvim_win_get_cursor(0)
        vim.cmd("normal! ]c")
        local after = vim.api.nvim_win_get_cursor(0)
        if before[1] == after[1] and before[2] == after[2] then
          actions.select_next_entry()
          vim.cmd("normal! gg")
          vim.cmd("normal! ]c")
        end
      end

      local function smart_prev()
        local before = vim.api.nvim_win_get_cursor(0)
        vim.cmd("normal! [c")
        local after = vim.api.nvim_win_get_cursor(0)
        if before[1] == after[1] and before[2] == after[2] then
          actions.select_prev_entry()
          vim.cmd("normal! G")
          vim.cmd("normal! [c")
        end
      end

      local function diff2_discard()
        local view = lib.get_current_view()
        if not (view and view:instanceof(DiffView)) then
          return
        end
        ---@cast view DiffView

        local file = view:infer_cur_file(false) or view.cur_entry
        if not file then
          return
        end

        if file.status == "?" then
          local ok = vim.fn.delete(file.absolute_path, "rf")
          if ok == 0 then
            actions.refresh_files()
          else
            vim.notify(("Failed to delete: %s"):format(file.absolute_path), vim.log.levels.ERROR)
          end
          return
        end

        local layout = view.cur_layout
        if not (layout and layout.a and layout.b) then
          return
        end

        local left_buf = layout.a.file and layout.a.file.bufnr
        local right_win = layout.b.id
        if not (left_buf and right_win and vim.api.nvim_buf_is_valid(left_buf)) then
          return
        end

        local cursor = vim.api.nvim_win_get_cursor(0)
        vim.api.nvim_win_call(right_win, function()
          if vim.api.nvim_win_is_valid(right_win) then
            pcall(vim.api.nvim_win_set_cursor, right_win, cursor)
          end
          vim.cmd("diffget " .. left_buf)
        end)

        layout:sync_scroll()
      end

      return {
        keymaps = {
          view = {
            -- stylua: ignore start
            { "n", "[h",        smart_prev,                        { desc = "Go to previous hunk" } },
            { "n", "]h",        smart_next,                        { desc = "Go to next hunk" } },
            { "n", "I",         smart_prev,                        { desc = "Go to previous hunk" } },
            { "n", "N",         smart_next,                        { desc = "Go to next hunk" } },
            { "n", "q",         actions.close,                     { desc = "Close Diffview" } },
            { "n", "<leader>e", actions.toggle_files,              { desc = "Toggle the file panel." } },
            { "n", "<c-u>",     actions.scroll_view(-0.25),        { desc = "Scroll the view up" } },
            { "n", "<c-d>",     actions.scroll_view(0.25),         { desc = "Scroll the view down" } },
            { "n", "g<",        function() vim.cmd("diffget") end, { desc = "Reject hunk (diffget)" } },
            { "n", "g>",        function() vim.cmd("diffput") end, { desc = "Apply hunk (diffput)" } },
            -- stylua: ignore end
          },
          diff2 = {
            -- stylua: ignore start
            { "n", "x", diff2_discard, { desc = "Discard hunk / delete untracked" } },
            -- stylua: ignore end
          },
          file_panel = {
            -- stylua: ignore start
            { "n", "<leader>e", actions.toggle_files,       { desc = "Toggle the file panel." } },
            { "n", "n",         actions.next_entry,         { desc = "Bring the cursor to the next file entry" } },
            { "n", "i",         actions.prev_entry,         { desc = "Bring the cursor to the previous file entry" } },
            { "n", "l",         actions.listing_style,      { desc = "Toggle between 'list' and 'tree' views" } },
            { "n", "<c-u>",     actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-d>",     actions.scroll_view(0.25),  { desc = "Scroll the view down" } },
            -- stylua: ignore end
          },
          file_history_panel = {
            -- stylua: ignore start
            { "n", "q", actions.close,      { desc = "Close Diffview" } },
            { "n", "n", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "i", actions.prev_entry, { desc = "Bring the cursor to the previous file entry" } },
            -- stylua: ignore end
          },
        },
      }
    end,
  },
}
