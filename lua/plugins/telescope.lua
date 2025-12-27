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
      local function live_grep_suffixes(prompt_bufnr)
        local picker = action_state.get_current_picker(prompt_bufnr)
        if not picker or type(picker.prompt_title) ~= "string" then
          return
        end
        local title = picker.prompt_title
        if not title:find("Live Grep", 1, true) then
          return
        end
        local default = title:match("^Live Grep %((.+)%)$") or ""
        local input_opts = { prompt = "File suffixes (comma): " }
        if default ~= "" then
          input_opts.default = default
        end
        vim.ui.input(input_opts, function(input)
          if input == nil then
            return
          end
          local args = {}
          local label = input:gsub("%s+", "")
          if label ~= "" then
            for ext in string.gmatch(label, "[^,%s]+") do
              local suffix = ext
              if suffix:sub(1, 1) == "." then
                suffix = "*" .. suffix
              else
                suffix = "*." .. suffix
              end
              table.insert(args, "-g")
              table.insert(args, suffix)
            end
          end
          actions.close(prompt_bufnr)
          vim.schedule(function()
            if label == "" or #args == 0 then
              builtin.live_grep()
              return
            end
            builtin.live_grep({
              additional_args = function()
                return args
              end,
              prompt_title = "Live Grep (" .. label .. ")",
            })
          end)
        end)
      end

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
          qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
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
              ["f"] = live_grep_suffixes,
              ["<C-q>"] = open_with_trouble_focus,
            },
          },
        },
      })
    end,
  },
}
