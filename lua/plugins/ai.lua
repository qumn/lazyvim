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
        codex = {
          env = {
            ALL_PROXY = "socks5://127.0.0.1:7890",
          },
        },
      },
      win = {
        keys = {
          buffers = { "<c-b>", "buffers", mode = "nt", desc = "open buffer picker" },
          files = { "<c-f>", "files", mode = "nt", desc = "open file picker" },
          hide_n = { "q", "hide", mode = "n", desc = "hide the terminal window" },
          hide_ctrl_q = { "<c-q>", "hide", mode = "n", desc = "hide the terminal window" },
          hide_ctrl_dot = { "<c-.>", "hide", mode = "nt", desc = "hide the terminal window" },
          hide_ctrl_z = { "<c-z>", "hide", mode = "nt", desc = "hide the terminal window" },
          prompt = { "<c-p>", "prompt", mode = "t", desc = "insert prompt or context" },
          stopinsert = { "<c-s>", "stopinsert", mode = "t", desc = "enter normal mode" },

          nav_left = { "<c-y>", "nav_left", expr = true, desc = "navigate to the left window" },
          nav_down = { "<c-n>", "nav_down", expr = true, desc = "navigate to the below window" },
          nav_up = { "<c-i>", "nav_up", expr = true, desc = "navigate to the above window" },
          nav_right = { "<c-o>", "nav_right", expr = true, desc = "navigate to the right window" },
        },
      },
    },
  },
  config = function(_, opts)
    require("sidekick").setup(opts)

    -- HACK: PERF disable opencode backend.
    -- Reason: opencode backend calls `lsof` to list *all* listening TCP processes, then
    -- runs `nvim_get_proc(pid)` for each PID to find "opencode". On some systems this
    -- is ~0.5–1s per refresh and blocks UI. I don't need opencode, so drop the backend.
    local ok, session = pcall(require, "sidekick.cli.session")
    if ok and session and type(session.register) == "function" then
      local orig_register = session.register
      ---@diagnostic disable-next-line: duplicate-set-field
      session.register = function(name, backend)
        if name == "opencode" then
          -- skip opencode registration entirely
          return
        end
        return orig_register(name, backend)
      end
    end
  end,
}
