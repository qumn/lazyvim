-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.norman")

-- tabs
vim.keymap.set({ "n", "t" }, "<leader>tn", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local is_overseer = vim.bo[bufnr].filetype == "OverseerList" or vim.b[bufnr].overseer_task ~= nil
  vim.cmd("tab split")
  if is_overseer then
    vim.t.overseer_allow_solo = true
  end
  vim.cmd("only")
end, {
  desc = "Open current window buffer fullscreen in a new tab (keep current layout)",
})
vim.keymap.set("n", "<leader>to", "<cmd>tabnext<cr>", { desc = "Next Tab" })
vim.keymap.set("n", "<leader>ty", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
vim.keymap.set("n", "<leader>tq", "<cmd>tabclose<cr>", { desc = "Close Tab" })

vim.keymap.set("v", "=", vim.lsp.buf.format, { silent = true })
vim.keymap.set("n", "==", vim.lsp.buf.format, { silent = true })

-- delete all marks for current line
vim.keymap.set({ "n" }, "md", function()
  -- delete buffer local marks
  local bufnr = vim.api.nvim_get_current_buf()
  local cur_line = vim.fn.line(".")
  ---@type { mark: string, pos: number[] }[]
  local all_marks_local = vim.fn.getmarklist(bufnr)
  for _, mark in ipairs(all_marks_local) do
    if mark.pos[2] == cur_line and string.match(mark.mark, "'[a-z]") then
      vim.api.nvim_buf_del_mark(bufnr, string.sub(mark.mark, 2, 2))
    end
  end

  -- delete global marks
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  ---@type { file: string, mark: string, pos: number[] }[]
  local all_marks_global = vim.fn.getmarklist()
  for _, mark in ipairs(all_marks_global) do
    local expanded_file_name = vim.fn.fnamemodify(mark.file, ":p")
    if bufname == expanded_file_name and mark.pos[2] == cur_line and string.match(mark.mark, "'[A-Z]") then
      vim.api.nvim_del_mark(string.sub(mark.mark, 2, 2))
    end
  end
end, { desc = "Delete all marks for current line" })

-- config for neovide, Macos using Cmd key for copy/paste
-- otherwise using Ctrl+Shift
if vim.g.neovide and vim.g.os_name ~= "Darwin" then
  vim.api.nvim_set_keymap("v", "<sc-c>", '"+y', { noremap = true })
  vim.api.nvim_set_keymap("n", "<sc-v>", 'l"+P', { noremap = true })
  vim.api.nvim_set_keymap("v", "<sc-v>", '"+P', { noremap = true })
  -- vim.api.nvim_set_keymap("c", "<sc-v>", '<C-o>l<C-o>"+<C-o>P<C-o>l', { noremap = true })
  vim.api.nvim_set_keymap("c", "<sc-v>", "<C-r>+", { noremap = true })
  vim.api.nvim_set_keymap("i", "<sc-v>", '<ESC>l"+Pli', { noremap = true })
  vim.api.nvim_set_keymap("t", "<sc-v>", '<C-\\><C-n>"+Pi', { noremap = true })
elseif vim.g.neovide and vim.g.os_name == "Darwin" then
  vim.api.nvim_set_keymap("v", "<D-c>", '"+y', { noremap = true })
  vim.api.nvim_set_keymap("n", "<D-v>", 'l"+P', { noremap = true })
  vim.api.nvim_set_keymap("v", "<D-v>", '"+P', { noremap = true })
  vim.api.nvim_set_keymap("c", "<D-v>", "<C-r>+", { noremap = true })
  vim.api.nvim_set_keymap("i", "<D-v>", '<ESC>l"+Pli', { noremap = true })
  vim.api.nvim_set_keymap("t", "<D-v>", '<C-\\><C-n>"+Pi', { noremap = true })
end

-- toggle case of word under cursor
local function toggle_case()
  local word = vim.fn.expand("<cword>")

  -- snake_case -> camelCase
  if word:find("_") then
    local camel = word:gsub("_(%w)", function(c)
      return c:upper()
    end)
    vim.cmd("normal! ciw" .. camel)
  else
    -- camelCase / PascalCase -> snake_case
    local snake = word:gsub("(%u)", "_%1"):gsub("^_", ""):lower()
    vim.cmd("normal! ciw" .. snake)
  end
end

vim.keymap.set("n", "gcs", toggle_case, { desc = "Toggle case of word under cursor" })

-- Keymaps
vim.keymap.set("n", "<C-=>", function()
  ResizeGuiFont(1)
end)
vim.keymap.set("n", "<C-->", function()
  ResizeGuiFont(-1)
end)

-- gui specialize config
RefreshGuiFont = function()
  vim.opt.guifont = string.format("%s:h%s", vim.g.gui_font_face, vim.g.gui_font_size)
end

ResizeGuiFont = function(delta)
  vim.g.gui_font_size = vim.g.gui_font_size + delta
  RefreshGuiFont()
end

ResetGuiFont = function()
  vim.g.gui_font_size = vim.g.gui_font_default_size
  RefreshGuiFont()
end

-- Call function on startup to set default value
ResetGuiFont()

local bottom = require("integrations.layout.bottom")
local bottom_owner_snacks = "snacks_terminal"

local function hide_snacks_terminals()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.terminal then
    return
  end
  for _, term in ipairs(snacks.terminal.list() or {}) do
    if term:valid() and term.opts and term.opts.position == "bottom" then
      term:hide()
    end
  end
end

local function snacks_bottom_visible()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.terminal then
    return false
  end
  for _, term in ipairs(snacks.terminal.list() or {}) do
    if term:win_valid() and term.opts and term.opts.position == "bottom" then
      return true
    end
  end
  return false
end

local function open_snacks_terminal()
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.terminal then
    return
  end
  snacks.terminal()
end

local function toggle_bottom_terminal()
  bottom.toggle({
    id = bottom_owner_snacks,
    open = open_snacks_terminal,
    hide = hide_snacks_terminals,
    is_open = snacks_bottom_visible,
  })
end

vim.keymap.set({ "n", "t" }, "<C-/>", toggle_bottom_terminal, { desc = "Toggle bottom terminal" })
vim.keymap.set({ "n", "t" }, "<C-_>", toggle_bottom_terminal, { desc = "which_key_ignore" })
