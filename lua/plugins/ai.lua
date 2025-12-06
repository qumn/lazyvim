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
          -- Navigate windows in terminal mode. Only active when:
          -- * layout is not "float"
          -- * there is another window in the direction
          -- With the default layout of "right", only `<c-h>` will be mapped
          nav_left = { "<c-y>", "nav_left", expr = true, desc = "navigate to the left window" },
          nav_down = { "<c-n>", "nav_down", expr = true, desc = "navigate to the below window" },
          nav_up = { "<c-i>", "nav_up", expr = true, desc = "navigate to the above window" },
          nav_right = { "<c-o>", "nav_right", expr = true, desc = "navigate to the right window" },
        },
      },
    },
  },
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
    {
      "<c-.>",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "Sidekick Toggle",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<leader>aa",
      function()
        require("sidekick.cli").toggle()
      end,
      desc = "Sidekick Toggle CLI",
    },
    {
      "<leader>as",
      function()
        require("sidekick.cli").select()
      end,
      -- Or to select only installed tools:
      -- require("sidekick.cli").select({ filter = { installed = true } })
      desc = "Select CLI",
    },
    {
      "<leader>ad",
      function()
        require("sidekick.cli").close()
      end,
      desc = "Detach a CLI Session",
    },
    {
      "<leader>at",
      function()
        require("sidekick.cli").send({ msg = "{this}" })
      end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>af",
      function()
        require("sidekick.cli").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("sidekick.cli").send({ msg = "{selection}" })
      end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>ap",
      function()
        require("sidekick.cli").prompt()
      end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    -- Example of a keybinding to open Claude directly
    {
      "<leader>ac",
      function()
        require("sidekick.cli").toggle({ name = "claude", focus = true })
      end,
      desc = "Sidekick Toggle Claude",
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
