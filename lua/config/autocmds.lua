-- Autocmds are aunntomatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- TODO waiting merge remove the autocmd
-- Use the more sane snippet session leave logic. Copied from:
-- https://github.com/L3MON4D3/LuaSnip/issues/258#issuecomment-1429989436
-- https://github.com/LazyVim/LazyVim/pull/2519/commits/5a708b199e9d487dd407ec3207e71b863371ad0d
vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*",
  callback = function()
    if
      ((vim.v.event.old_mode == "s" and vim.v.event.new_mode == "n") or vim.v.event.old_mode == "i")
      and require("luasnip").session.current_nodes[vim.api.nvim_get_current_buf()]
      and not require("luasnip").session.jump_active
    then
      require("luasnip").unlink_current()
    end
  end,
})

vim.api.nvim_create_autocmd("InsertEnter", {
  pattern = "*",
  callback = function()
    -- vim.lsp.inlay_hint.enable(false)
    LazyVim.toggle.inlay_hints(vim.api.nvim_get_current_buf(), false)
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    -- vim.lsp.inlay_hint.enable(true)
    LazyVim.toggle.inlay_hints(vim.api.nvim_get_current_buf(), true)
  end,
})

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
  group = vim.api.nvim_create_augroup("Color", {}),
  pattern = "*",
  callback = function()
    -- local colorscheme = vim.g.colors_name
    -- print(string.format("colorscheme %s", colorscheme))
    require("config.highlight").load_syntax()
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    -- local colorscheme = vim.g.colors_name
    -- print(string.format("colorscheme %s", colorscheme))
    print("VeryLazy event fired")
    require("config.highlight").load_syntax()
  end,
})

LazyVim.on_very_lazy(function()
  print("VeryLazy event fired")
end)
