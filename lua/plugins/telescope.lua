return {
  {
    "nvim-telescope/telescope.nvim",
    init = function()
      -- HACK: Telescope uses `nvim_replace_termcodes()` when applying mappings, so <C-i>/<Tab> can normalize to the same lhs.
      -- Bind after `FileType TelescopePrompt` to keep them distinct in the prompt buffer.
      local group = vim.api.nvim_create_augroup("UserTelescopeTabCi", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "TelescopePrompt",
        callback = function(ev)
          local actions = require("telescope.actions")
          vim.keymap.set({ "i", "n" }, "<Tab>", function()
            return actions.move_selection_next(ev.buf)
          end, { buffer = ev.buf, silent = true })
          vim.keymap.set({ "i", "n" }, "<C-i>", function()
            return actions.move_selection_previous(ev.buf)
          end, { buffer = ev.buf, silent = true })
        end,
      })
    end,
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
      {
        "ss",
        function()
          require("telescope.builtin").lsp_document_symbols({
            symbols = LazyVim.config.get_kind_filter(),
          })
        end,
        desc = "Goto Symbol",
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
