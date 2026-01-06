vim.schedule(function()
  vim.keymap.set("n", "i", "k", { buffer = 0, silent = true, nowait = true })
end)
