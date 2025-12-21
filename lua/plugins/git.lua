return {
  {
    "lewis6991/gitsigns.nvim",
    event = "LazyFile",
    opts = {
      attach_to_untracked = true,
      signs_staged_enable = true,
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
      local difftool = require("integrations.diffview.difftool")
      local fns = difftool.diffview_fns(actions)
      return {
        keymaps = {
          view = {
            -- stylua: ignore start
            { "n", "[h",        fns.smart_prev,                    { desc = "Go to previous hunk" } },
            { "n", "]h",        fns.smart_next,                    { desc = "Go to next hunk" } },
            { "n", "I",         fns.smart_prev,                    { desc = "Go to previous hunk" } },
            { "n", "N",         fns.smart_next,                    { desc = "Go to next hunk" } },
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
            { "n", "x", fns.diff2_discard, { desc = "Discard hunk / delete untracked" } },
            { "n", "s", fns.diff2_stage,   { desc = "Stage/Unstage hunk" } },
            { "n", "<c-s>", fns.diff2_write_both, { desc = "Write worktree/index without autocmd" } },
          },
          file_panel = {
            -- stylua: ignore start
            { "n", "<leader>e", actions.toggle_files,       { desc = "Toggle the file panel." } },
            { "n", "q",         actions.close,              { desc = "Close Diffview" } },
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
            { "n", "<c-u>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-d>", actions.scroll_view(0.25),  { desc = "Scroll the view down" } },
            -- stylua: ignore end
          },
        },
      }
    end,
  },
}
