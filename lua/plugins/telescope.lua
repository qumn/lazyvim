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
      {
        "se",
        "<CMD>Telescope oldfiles<CR>",
        desc = "Recent",
      },
      {
        "sb",
        "<CMD>Telescope buffers<CR>",
        desc = "Buffers",
      },
    },
    opts = function(_, opts)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
      local builtin = require("telescope.builtin")
      local trouble_telescope = require("trouble.sources.telescope")
      local function open_with_trouble_focus(prompt_bufnr)
        trouble_telescope.open(prompt_bufnr, { focus = true, source = "telescope" })
        vim.schedule(function()
          local mode = trouble_telescope.mode()
          ---@diagnostic disable-next-line: missing-parameter, missing-fields
          require("trouble").first({ mode = mode, focus = true, source = "telescope" })
        end)
      end

      local prev = "<C-i>"
      local telescope_suffixes = require("integrations.telescope.suffixes").new(builtin)

      local jdtls_telescope = require("integrations.telescope.jdtls")
      local qflist_previewer_with_jdt = jdtls_telescope.setup(builtin)

      return vim.tbl_extend("force", opts, {
        defaults = {
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
          qflist_previewer = qflist_previewer_with_jdt,
          winblend = 0,
          path_display = {
            filename_first = {
              reverse_directories = true,
            },
          },
          mappings = {
            i = {
              ["<C-s>"] = actions.select_horizontal,
              ["<C-n>"] = actions.move_selection_next,
              [prev] = actions.move_selection_previous,
              ["<C-q>"] = open_with_trouble_focus,
            },
            n = {
              ["n"] = actions.move_selection_next,
              ["i"] = actions.move_selection_previous,
              ["Y"] = actions.move_to_top,
              ["M"] = actions.move_to_middle,
              ["O"] = actions.move_to_bottom,
              ["s"] = actions.select_horizontal,
              ["v"] = actions.select_vertical,
              ["f"] = telescope_suffixes,
              ["<C-q>"] = open_with_trouble_focus,
            },
          },
        },
      })
    end,
  },
}
