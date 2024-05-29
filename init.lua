-- bootstrap lazy.nvim, LazyVim and your plugins

-- distinguish Tab and C-i
vim.keymap.set("", "<Tab>", "<Tab>")
vim.keymap.set("", "<C-i>", "<C-i>")
require("config.lazy")
