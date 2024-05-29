return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- add a keymap to browse plugin files
      -- stylua: ignore
      {
        "<leader>fp",
        function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
        desc = "Find Plugin File",
      },
    },
    -- change some options
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
    config = function()
      local actions = require("telescope.actions")
      local prev = "<C-i>"
      require("telescope").setup({
        defaults = {
          -- layout_config = {
          --   horizontal = { prompt_position = 'top', results_width = 0.6 },
          --   vertical = { mirror = false },
          -- },
          theme = "ivy",
          sorting_strategy = "ascending",
          layout_strategy = "bottom_pane",
          layout_config = {
            height = 0.5,
          },
          border = true,
          borderchars = {
            prompt = { "─", " ", " ", " ", "─", "─", " ", " " },
            results = { " " },
            preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
          },
          file_previewer = require("telescope.previewers").vim_buffer_cat.new,
          grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
          qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
          mappings = {
            i = {
              ["<C-s>"] = actions.select_horizontal,
              ["<C-n>"] = actions.move_selection_next,
              [prev] = actions.move_selection_previous,
            },
            n = {
              ["n"] = actions.move_selection_next,
              ["i"] = actions.move_selection_previous,
              ["Y"] = actions.move_to_top,
              ["M"] = actions.move_to_middle,
              ["O"] = actions.move_to_bottom,
              ["s"] = actions.select_horizontal,
              ["v"] = actions.select_vertical,
            },
          },
        },
      })
    end,
  },
}
