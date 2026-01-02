return {
  "mrjones2014/smart-splits.nvim",
  dependencies = { "pogyomo/submode.nvim" },
  event = "BufRead",
  enable = not vim.g.neovide,
  init = function()
    local map = vim.keymap.set
    -- stylua: ignore start
    map({ "n", "t" },   "<C-y>",   require("smart-splits").move_cursor_left,     { desc = "Move to left split" })
    map({ "n", "t" },   "<C-n>",   require("smart-splits").move_cursor_down,     { desc = "Move to down split" })
    map({ "n", "t" },   "<C-i>",   require("smart-splits").move_cursor_up,       { desc = "Move to up split" })
    map({ "n", "t" },   "<C-o>",   require("smart-splits").move_cursor_right,    { desc = "Move to right split" })
    map({ "n", "t" },   "<C-\\>",  require("smart-splits").move_cursor_previous, { desc = "Move to previous split" })
    map("t",   "<Tab>", [[<Tab>]], { desc = "Keep Tab is Tab" })

    map({ "n", "t" },   "<C-S-Y>", require("smart-splits").resize_left,          { desc = "Resize split left" })
    map({ "n", "t" },   "<C-S-N>", require("smart-splits").resize_down,          { desc = "Resize split down" })
    map({ "n", "t" },   "<C-S-I>", require("smart-splits").resize_up,            { desc = "Resize split up" })
    map({ "n", "t" },   "<C-S-O>", require("smart-splits").resize_right,         { desc = "Resize split right" })

    map({ "n", "t" },   "<C-w>y",  require("smart-splits").swap_buf_left,        { desc = "Swap buffer left" })
    map({ "n", "t" },   "<C-w>n",  require("smart-splits").swap_buf_down,        { desc = "Swap buffer down" })
    map({ "n", "t" },   "<C-w>i",  require("smart-splits").swap_buf_up,          { desc = "Swap buffer up" })
    map({ "n", "t" },   "<C-w>o",  require("smart-splits").swap_buf_right,       { desc = "Swap buffer right" })
    -- stylua: ignore end

    -- Resize
    local submode = require("submode")
    submode.create("WinResize", {
      mode = "n",
      enter = "<C-w>r",
      leave = { "<Esc>", "q", "<C-c>" },
      hook = {
        on_enter = function()
          vim.notify("Use { y, n, i, o } or { <Left>, <Down>, <Up>, <Right> } to resize the window")
        end,
        on_leave = function()
          vim.notify("")
        end,
      },
      default = function(register)
        register("y", require("smart-splits").resize_left, { desc = "Resize left" })
        register("n", require("smart-splits").resize_down, { desc = "Resize down" })
        register("i", require("smart-splits").resize_up, { desc = "Resize up" })
        register("o", require("smart-splits").resize_right, { desc = "Resize right" })
        register("s", "<CMD>split<CR>", { desc = "Create horizontal split" })
        register("v", "<CMD>vsplit<CR>", { desc = "Create vertical split" })
        register("f", "<CMD>Telescope find_files<CR>", { desc = "Find files" })
        register("<Left>", require("smart-splits").resize_left, { desc = "Resize left" })
        register("<Down>", require("smart-splits").resize_down, { desc = "Resize down" })
        register("<Up>", require("smart-splits").resize_up, { desc = "Resize up" })
        register("<Right>", require("smart-splits").resize_right, { desc = "Resize right" })
      end,
    })
  end,
}
