return {
  {
    "saghen/blink.cmp",
    opts = {
      cmdline = {
        keymap = {
          preset = "none",
          ["<C-i>"] = { "select_prev", "fallback_to_mappings" },
          ["<C-n>"] = { "select_next", "fallback_to_mappings" },
          ["<Tab>"] = { "select_next", "fallback_to_mappings" },
        },
      },
      keymap = {
        preset = "none",
        ["<C-k>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },

        ["<Tab>"] = {
          function(cmp)
            -- if menu is visible and item is manually selected, priority accept it
            local list = require("blink.cmp.completion.list")
            local explicit = list.is_explicitly_selected
            if type(explicit) == "function" then
              explicit = explicit()
            end
            local is_manual_selected = cmp.is_menu_visible() and (explicit == true)
            if is_manual_selected then
              return cmp.accept()
            end

            return LazyVim.cmp.map({
              "snippet_forward",
              "ai_nes",
              "ai_accept",
            })() or cmp.select_and_accept()
          end,
          "fallback",
        },
        ["<CR>"] = { "accept", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },

        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<C-i>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },

        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
      },
      completion = {
        ghost_text = {
          enabled = true,
        },
        list = {
          selection = {
            -- not preselect if snippet is active
            preselect = function(_)
              return not require("blink.cmp").snippet_active({ direction = 1 })
            end,
          },
        },
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        menu = {
          border = "rounded",
          direction_priority = function()
            local ctx = require("blink.cmp").get_context()
            local item = require("blink.cmp").get_selected_item()
            if ctx == nil or item == nil then
              return { "s", "n" }
            end

            local item_text = item.textEdit ~= nil and item.textEdit.newText or item.insertText or item.label
            local is_multi_line = item_text:find("\n") ~= nil

            -- after showing the menu upwards, we want to maintain that direction
            -- until we re-open the menu, so store the context id in a global variable
            if is_multi_line or vim.g.blink_cmp_upwards_ctx_id == ctx.id then
              vim.g.blink_cmp_upwards_ctx_id = ctx.id
              return { "n", "s" }
            end
            return { "s", "n" }
          end,
          draw = {
            -- padding = 1,
            -- gap = 4,
            columns = { { "kind_icon", "label", "label_description", gap = 1 } },
            components = {
              kind = {
                text = function(ctx)
                  local len = 10 - string.len(ctx.kind)
                  local space = string.rep(" ", len)
                  return ctx.kind .. space .. "[" .. ctx.source_name .. "]"
                end,
              },
            },
          },
        },
      },
    },
  },
}
