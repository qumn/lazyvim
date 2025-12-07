return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.styles = opts.styles or {}
    opts.styles.terminal = opts.styles.terminal or {}
    opts.styles.terminal.keys = opts.styles.terminal.keys or {}

    -- disable default keymap
    opts.styles.terminal.keys.nav_h = false
    opts.styles.terminal.keys.nav_j = false
    opts.styles.terminal.keys.nav_k = false
    opts.styles.terminal.keys.nav_l = false

    opts.terminal = opts.terminal or {}
    opts.terminal.win = opts.terminal.win or {}
    opts.terminal.win.keys = opts.terminal.win.keys or {}
    opts.terminal.win.keys.nav_h = false
    opts.terminal.win.keys.nav_j = false
    opts.terminal.win.keys.nav_k = false
    opts.terminal.win.keys.nav_l = false

    -- -- keymap for norman
    -- vim.keymap.set("t", "<C-y>", [[<C-\><C-n><C-w>h]], { silent = true, desc = "Term: left window" })
    -- vim.keymap.set("t", "<C-n>", [[<C-\><C-n><C-w>j]], { silent = true, desc = "Term: down window" })
    -- vim.keymap.set("t", "<C-i>", [[<C-\><C-n><C-w>k]], { silent = true, desc = "Term: up window" })
    -- vim.keymap.set("t", "<C-o>", [[<C-\><C-n><C-w>l]], { silent = true, desc = "Term: right window" })
    -- vim.keymap.set("t", "<Tab>", [[<Tab>]], { silent = true, desc = "Keep tab is tab" })
  end,
}
