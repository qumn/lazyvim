vim.o.wrap = false
vim.opt.conceallevel = 3

local function pad_to_eol(str)
  local win_width = vim.api.nvim_win_get_width(0) -- current window width
  local str_width = vim.fn.strdisplaywidth(str) -- visual width of the string
  local spaces_needed = win_width - str_width

  if spaces_needed > 0 then
    return str .. string.rep(" ", spaces_needed)
  else
    return str
  end
end

local function fold_virt_text(result, start_text, lnum)
  -- extmarks highlight
  local ns_id = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
  local extmarks = vim.api.nvim_buf_get_extmarks(0, ns_id, { lnum, 0 }, { lnum, 0 }, { details = true })
  local details = extmarks[#extmarks][4] or {}
  local ext_hl_str
  if details then
    ext_hl_str = details.hl_group
  end

  -- ts highlight
  local captured_highlights = vim.treesitter.get_captures_at_pos(0, lnum, 0)
  local ts_hl_str = "@" .. captured_highlights[#captured_highlights].capture .. ".markdown"
  ts_hl_str = vim.api.nvim_get_hl(0, { name = ts_hl_str, link = true }).link

  -- merge highlight
  local ext_hl = vim.api.nvim_get_hl(0, { name = ext_hl_str })
  local ts_hl = vim.api.nvim_get_hl(0, { name = ts_hl_str })

  -- Create a combined group
  vim.api.nvim_set_hl(0, "MyMergedHL", { fg = ts_hl.fg, bg = ext_hl.bg })
  vim.api.nvim_set_hl(0, "MyInvertMergeHL", { fg = ext_hl.bg, bg = nil })
  table.insert(result, { pad_to_eol(start_text), "MyMergedHL" })
end

function _G.markdown_foldtext()
  local start_text = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop))
  local result = {}
  fold_virt_text(result, start_text, vim.v.foldstart - 1)
  return result
end
vim.opt.foldtext = "v:lua.markdown_foldtext()"
vim.o.fillchars = [[eob: ,fold: ,foldopen: ,foldsep: ,foldclose: ]]
