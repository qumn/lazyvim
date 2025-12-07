return {
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
        },
      },
    },
  },
  config = function(_, opts)
    local proxy_env = {
      ALL_PROXY = "socks5://127.0.0.1:7890",
      HTTP_PROXY = "http://127.0.0.1:7890",
      HTTPS_PROXY = "http://127.0.0.1:7890",
    }
    if proxy_env and next(proxy_env) then
      for _, tool in pairs(opts.cli.tools or {}) do
        tool.env = vim.tbl_extend("force", tool.env or {}, proxy_env)
      end
    end
    require("sidekick").setup(opts)
  end,
}
