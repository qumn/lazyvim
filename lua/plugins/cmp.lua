return {
  {
    "onsails/lspkind.nvim",
    config = function()
      -- setup lspkind for Copilot icon
      require("lspkind").init({
        symbol_map = {
          Copilot = "",
        },
      })
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "onsails/lspkind.nvim",
    },
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
            if cmp.snippet_active() then
              return cmp.accept()
            else
              return cmp.select_and_accept()
            end
          end,
          -- setup for Copilot native integration
          LazyVim.cmp.map({ "snippet_forward", "ai_nes", "ai_accept" }),
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
              kind_icon = {
                ellipsis = false,
                text = function(ctx)
                  return require("lspkind").symbolic(ctx.kind, {
                    mode = "symbol",
                  }) .. " "
                end,
              },
            },
          },
        },
      },
    },
  },
}
