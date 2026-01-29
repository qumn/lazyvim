local function enabled()
  return vim.g.copilot_enabled == true
end

return {
  {
    "fang2hou/blink-copilot",
    enabled = enabled,
    lazy = true,
  },
  {
    "folke/sidekick.nvim",
    opts = function(_, opts)
      opts = opts or {}
      opts.nes = opts.nes or {}
      opts.nes.enabled = enabled()
      return opts
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "fang2hou/blink-copilot" },
    opts = function(_, opts)
      if not enabled() then
        return opts
      end

      opts = opts or {}
      opts.sources = opts.sources or {}
      opts.sources.default = opts.sources.default or { "lsp", "path", "snippets", "buffer" }

      local has_copilot = false
      for _, src in ipairs(opts.sources.default) do
        if src == "copilot" then
          has_copilot = true
          break
        end
      end
      if not has_copilot then
        table.insert(opts.sources.default, 1, "copilot")
      end

      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.copilot = {
        name = "copilot",
        module = "blink-copilot",
        score_offset = 10000,
        async = true,
      }

      return opts
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      if not enabled() then
        return opts
      end
      opts = opts or {}
      opts.ensure_installed = opts.ensure_installed or {}
      for _, name in ipairs(opts.ensure_installed) do
        if name == "copilot-language-server" then
          return opts
        end
      end
      table.insert(opts.ensure_installed, "copilot-language-server")
      return opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      if not enabled() then
        return opts
      end

      opts = opts or {}
      opts.servers = opts.servers or {}
      opts.servers.copilot = opts.servers.copilot or {}
      opts.servers.copilot.keys = opts.servers.copilot.keys or {}
      vim.list_extend(opts.servers.copilot.keys, {
        {
          "<M-]>",
          function()
            vim.lsp.inline_completion.select({ count = 1 })
          end,
          desc = "Next Copilot Suggestion",
          mode = { "i", "n" },
        },
        {
          "<M-[>",
          function()
            vim.lsp.inline_completion.select({ count = -1 })
          end,
          desc = "Prev Copilot Suggestion",
          mode = { "i", "n" },
        },
      })

      opts.setup = opts.setup or {}
      local orig = opts.setup.copilot
      opts.setup.copilot = function(_, server_opts)
        if type(orig) == "function" then
          orig(_, server_opts)
        end

        vim.schedule(function()
          vim.lsp.inline_completion.enable()
        end)

        local group = vim.api.nvim_create_augroup("CopilotInlineCompletion", { clear = true })
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "BlinkCmpMenuOpen",
          callback = function()
            vim.lsp.inline_completion.display(false, { bufnr = 0 })
            vim.b.copilot_suggestion_hidden = true
          end,
        })
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "BlinkCmpMenuClose",
          callback = function()
            vim.defer_fn(function()
              vim.lsp.inline_completion.display(true, { bufnr = 0 })
              vim.b.copilot_suggestion_hidden = false
            end, 50)
          end,
        })

        if LazyVim and LazyVim.cmp and LazyVim.cmp.actions then
          LazyVim.cmp.actions.ai_accept = function()
            return vim.lsp.inline_completion.get()
          end
        end
      end

      return opts
    end,
  },
}
