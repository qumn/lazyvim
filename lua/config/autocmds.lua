-- Autocmds are aunntomatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- TODO waiting merge remove the autocmd
-- Use the more sane snippet session leave logic. Copied from:
-- https://github.com/L3MON4D3/LuaSnip/issues/258#issuecomment-1429989436
-- https://github.com/LazyVim/LazyVim/pull/2519/commits/5a708b199e9d487dd407ec3207e71b863371ad0d
-- vim.api.nvim_create_autocmd("ModeChanged", {
--   pattern = "*",
--   callback = function()
--     if
--       ((vim.v.event.old_mode == "s" and vim.v.event.new_mode == "n") or vim.v.event.old_mode == "i")
--       and require("luasnip").session.current_nodes[vim.api.nvim_get_current_buf()]
--       and not require("luasnip").session.jump_active
--     then
--       require("luasnip").unlink_current()
--     end
--   end,
-- })

-- vim.api.nvim_create_autocmd("InsertEnter", {
--   pattern = "*",
--   callback = function()
--     -- vim.lsp.inlay_hint.enable(false)
--     LazyVim.toggle.inlay_hints(vim.api.nvim_get_current_buf(), false)
--   end,
-- })
--
-- vim.api.nvim_create_autocmd("InsertLeave", {
--   pattern = "*",
--   callback = function()
--     -- vim.lsp.inlay_hint.enable(true)
--     LazyVim.toggle.inlay_hints(vim.api.nvim_get_current_buf(), true)
--   end,
-- })

local group = vim.api.nvim_create_augroup("custom_everforest_hl", { clear = true })

vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  pattern = "everforest",
  callback = function()
    require("config.highlight").setup()
  end,
})

if vim.g.colors_name == "everforest" then
  vim.schedule(function()
    require("config.highlight").setup()
  end)
end

-- If a tab ends up with only Overseer panes, close the tab to avoid Overseer becoming the last window.
vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("OverseerCloseIfLastWindow", { clear = true }),
  callback = function()
    if vim.t.overseer_allow_solo then
      return
    end
    local winids = vim.api.nvim_tabpage_list_wins(0)
    local panes = {}
    for _, winid in ipairs(winids) do
      local cfg = vim.api.nvim_win_get_config(winid)
      if not cfg.relative or cfg.relative == "" then
        table.insert(panes, winid)
      end
    end
    if #panes == 0 then
      return
    end
    for _, winid in ipairs(panes) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local ft = vim.bo[bufnr].filetype
      if ft ~= "OverseerList" and not vim.b[bufnr].overseer_task then
        return
      end
      if vim.bo[bufnr].modified then
        return
      end
    end
    vim.schedule(function()
      local target = panes[1]
      if target and vim.api.nvim_win_is_valid(target) then
        pcall(vim.api.nvim_set_current_win, target)
      end
      pcall(vim.cmd.quit)
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    -- Unmap <CR> in quickfix window (if needed)
    vim.keymap.set("n", "<CR>", "<CR>", { buffer = true, desc = "Default Enter in quickfix" })
    -- Enable cursorline only in quickfix window
    vim.opt_local.cursorline = true
  end,
})
