return {
  {
    "gbprod/yanky.nvim",
    recommended = true,
    desc = "Better Yank/Paste",
    event = "LazyFile",
    opts = {
      highlight = { timer = 150 },
    },
    keys = {
      -- stylua: ignore start
      { "<leader>p", function() require("telescope").extensions.yank_history.yank_history({ }) end, desc = "Open Yank History" },
      { "p",  "<Plug>(YankyPutAfter)",                  mode = { "n", "x" }, desc = "Put Yanked Text After Cursor" },
      { "P",  "<Plug>(YankyPutBefore)",                 mode = { "n", "x" }, desc = "Put Yanked Text Before Cursor" },
      { "gp", "<Plug>(YankyGPutAfter)",                 mode = { "n", "x" }, desc = "Put Yanked Text After Selection" },
      { "gP", "<Plug>(YankyGPutBefore)",                mode = { "n", "x" }, desc = "Put Yanked Text Before Selection" },
      { "[y", "<Plug>(YankyCycleForward)",              desc = "Cycle Forward Through Yank History" },
      { "]y", "<Plug>(YankyCycleBackward)",             desc = "Cycle Backward Through Yank History" },
      { "]p", "<Plug>(YankyPutIndentAfterLinewise)",    desc = "Put Indented After Cursor (Linewise)" },
      { "[p", "<Plug>(YankyPutIndentBeforeLinewise)",   desc = "Put Indented Before Cursor (Linewise)" },
      { "]P", "<Plug>(YankyPutIndentAfterLinewise)",    desc = "Put Indented After Cursor (Linewise)" },
      { "[P", "<Plug>(YankyPutIndentBeforeLinewise)",   desc = "Put Indented Before Cursor (Linewise)" },
      { ">p", "<Plug>(YankyPutIndentAfterShiftRight)",  desc = "Put and Indent Right" },
      { "<p", "<Plug>(YankyPutIndentAfterShiftLeft)",   desc = "Put and Indent Left" },
      { ">P", "<Plug>(YankyPutIndentBeforeShiftRight)", desc = "Put Before and Indent Right" },
      { "<P", "<Plug>(YankyPutIndentBeforeShiftLeft)",  desc = "Put Before and Indent Left" },
      { "=p", "<Plug>(YankyPutAfterFilter)",            desc = "Put After Applying a Filter" },
      { "=P", "<Plug>(YankyPutBeforeFilter)",           desc = "Put Before Applying a Filter" },
      -- stylua: ignore end
    },
  },
  {
    "junegunn/vim-easy-align",
    event = "BufRead",
    keys = {
      { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "EasyAlign" },
    },
  },
  {
    "MagicDuck/grug-far.nvim",
    opts = { headerMaxWidth = 80 },
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      { "<leader>sr", false },
      {
        "<leader>fr",
        function()
          local grug = require("grug-far")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          grug.open({
            transient = true,
            prefills = {
              filesFilter = ext and ext ~= "" and "*." .. ext or nil,
            },
          })
        end,
        mode = { "n", "x" },
        desc = "Search and Replace",
      },
    },
  },
  {
    "folke/trouble.nvim",
    opts = {
      config = function()
        local main = require("trouble.view.main")
        local preview = require("trouble.view.preview")

        -- HACK: override Trouble main-window detection for snacks_dashboard.
        main._valid = function(win, buf)
          if not win or not buf then
            return false
          end
          if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
            return false
          end
          if vim.api.nvim_win_get_buf(win) ~= buf then
            return false
          end
          if preview.is_win(win) or vim.w[win].trouble then
            return false
          end
          if vim.api.nvim_win_get_config(win).relative ~= "" then
            return false
          end

          -- Allow snacks_dashboard to be main even with buftype=nofile.
          local bt = vim.bo[buf].buftype
          if bt ~= "" then
            return bt == "nofile" and vim.bo[buf].filetype == "snacks_dashboard"
          end
          return true
        end
      end,

      win = {
        position = "bottom",
        size = 0.4,
        keys = {
          i = false,
        },
      },
      keys = {
        n = "next",
        i = "prev",
      },
    },
  },
}
