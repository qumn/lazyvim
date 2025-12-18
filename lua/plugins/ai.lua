local PROXY_ENV = {
  ALL_PROXY = "socks5://127.0.0.1:7890",
  HTTP_PROXY = "http://127.0.0.1:7890",
  HTTPS_PROXY = "http://127.0.0.1:7890",
}

local function codex_acp_command(reasoning_effort)
  return {
    "codex-acp",
    "-c",
    ('model_reasoning_effort="%s"'):format(reasoning_effort),
  }
end

return {
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        picker = "telescope",
        mux = {
          backend = "tmux",
          enabled = true,
        },
        tools = {
          -- ensure tools exist so env merging runs
          codex = {},
          opencode = {},
        },
        win = {
          keys = {
            buffers = { "<c-b>", "buffers", mode = "nt", desc = "open buffer picker" },
            files = { "<c-f>", "files", mode = "nt", desc = "open file picker" },
            hide_n = { "q", "hide", mode = "n", desc = "hide the terminal window" },
            hide_ctrl_q = { "<c-q>", "hide", mode = "n", desc = "hide the terminal window" },
            hide_ctrl_dot = { "<c-.>", "hide", mode = "nt", desc = "hide the terminal window" },
            hide_ctrl_z = { "<c-z>", "hide", mode = "nt", desc = "hide the terminal window" },
            prompt = { "<cs-p>", "prompt", mode = "t", desc = "insert prompt or context" },
            stopinsert = { "<c-s>", "stopinsert", mode = "t", desc = "enter normal mode" },

            nav_left = { "<c-y>", "nav_left", expr = true, desc = "navigate to the left window" },
            nav_down = { "<c-n>", "nav_down", expr = true, desc = "navigate to the below window" },
            nav_up = { "<c-i>", "nav_up", expr = true, desc = "navigate to the above window" },
            nav_right = { "<c-o>", "nav_right", expr = true, desc = "navigate to the right window" },
            nav_tab = { "<Tab>", "<Tab>", desc = "Keep Tab to Tab" },

            -- HACK: codex cannot custome key, so we intercept these keys to send to codex
            codex_stop = { "<c-c>", "<Esc>", desc = "stop codex generation" },
            codex_esc = { "<Esc>", "<C-\\><C-n>", desc = "escape to normal mode" },
            codex_newline = { "<Enter>", "<C-j>", desc = "insert newline" },
            codex_send = { "<C-Enter>", "<Enter>", desc = "send prompt" },
          },
        },
      },
    },
    config = function(_, opts)
      if PROXY_ENV and next(PROXY_ENV) then
        for _, tool in pairs(opts.cli.tools or {}) do
          tool.env = vim.tbl_extend("force", tool.env or {}, PROXY_ENV)
        end
      end
      require("sidekick").setup(opts)
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
      "CodeCompanionCmd",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "franco-ruggeri/codecompanion-spinner.nvim",
    },

    config = function()
      require("codecompanion").setup({
        interactions = {
          background = { adapter = "codex" },
          chat = { adapter = "codex" },
          inline = { adapter = "codex" },
          cmd = { adapter = "codex" },
        },
        adapters = {
          acp = {
            codex = function()
              return require("codecompanion.adapters").extend("codex", {
                defaults = {
                  auth_method = "chatgpt",
                },
                env = PROXY_ENV,
                commands = {
                  low = codex_acp_command("low"),
                  medium = codex_acp_command("medium"),
                  high = codex_acp_command("high"),
                  xhigh = codex_acp_command("xhigh"),
                },
              })
            end,
          },
        },
        extensions = {
          spinner = {},
        },
      })

      require("integrations.codecompanion.elapsed").setup()
    end,
  },
}
