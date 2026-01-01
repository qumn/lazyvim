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
        local telescope_source = require("trouble.sources.telescope")

        -- Trouble rejects buftype=nofile as "main"; allow snacks_dashboard and URI buffers to be treated as main.
        ---@diagnostic disable-next-line: duplicate-set-field
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
            if bt ~= "nofile" then
              return false
            end
            local ft = vim.bo[buf].filetype
            if ft == "snacks_dashboard" then
              return true
            end
            local name = vim.api.nvim_buf_get_name(buf)
            return name:match("^jdt:") ~= nil or name:match("^jar:") ~= nil or name:match("^zipfile:") ~= nil
          end
          return true
        end

        -- Some code paths collapse `//` in filenames, turning `jdt://...` into `jdt:/...`.
        -- nvim-jdtls uses `BufReadCmd jdt://*`, so canonicalize JDT URIs to `jdt://...`.
        local function canonical_jdt_uri(name)
          if type(name) ~= "string" then
            return nil
          end
          if not name:match("^jdt:") then
            return nil
          end
          if name:match("^jdt://") then
            return name
          end
          local rest = name:sub(5)
          rest = rest:gsub("^/+", "")
          return "jdt://" .. rest
        end

        local orig_item = telescope_source.item
        -- Ensure JDT telescope items carry a stable `bufnr` so Trouble jump/preview doesn't treat the URI as a file path.
        telescope_source.item = function(item)
          local filename
          if item.path then
            filename = item.path
          else
            filename = item.filename
            if item.cwd and filename then
              filename = item.cwd .. "/" .. filename
            end
          end

          local uri = canonical_jdt_uri(filename)
          if uri then
            item.path = uri
            if not item.bufnr or item.bufnr <= 0 then
              item.bufnr = vim.uri_to_bufnr(uri)
            end
          end

          return orig_item(item)
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
