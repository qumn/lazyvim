return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "copilot-language-server" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        copilot = {
          keys = {
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
          },
        },
      },
      setup = {
        copilot = function()
          vim.schedule(function()
            vim.lsp.inline_completion.enable()
          end)
          -- Hide Copilot on suggestion
          vim.api.nvim_create_autocmd("User", {
            pattern = "BlinkCmpMenuOpen",
            callback = function()
              vim.lsp.inline_completion.display(false, { bufnr = 0 })
              vim.b.copilot_suggestion_hidden = true
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            pattern = "BlinkCmpMenuClose",
            callback = function()
              vim.defer_fn(function()
                vim.lsp.inline_completion.display(true, { bufnr = 0 })
                vim.b.copilot_suggestion_hidden = false
              end, 50)
            end,
          })
          -- Accept inline suggestions or next edits
          LazyVim.cmp.actions.ai_accept = function()
            return vim.lsp.inline_completion.get()
          end
        end,
      },
    },
  },
}
