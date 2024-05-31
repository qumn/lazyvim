local M = {}
M.highlight = {
  PmenuSel = { bg = "#282C34", fg = "NONE" },
  Pmenu = { fg = "#C5CDD9", bg = "#22252A" },

  CmpItemAbbrDeprecated = { fg = "#7E8294", strikethrough = true },
  CmpItemAbbrMatch = { fg = "#82AAFF", bold = true },
  CmpItemAbbrMatchFuzzy = { fg = "#82AAFF", bold = true },
  CmpItemMenu = { fg = "#C792EA", italic = true },

  CmpItemKindField = { fg = "#EED8DA", bg = "#B5585F" },
  CmpItemKindProperty = { fg = "#EED8DA", bg = "#B5585F" },
  CmpItemKindEvent = { fg = "#EED8DA", bg = "#B5585F" },

  CmpItemKindText = { fg = "#C3E88D", bg = "#9FBD73" },
  CmpItemKindEnum = { fg = "#C3E88D", bg = "#9FBD73" },
  CmpItemKindKeyword = { fg = "#C3E88D", bg = "#9FBD73" },

  CmpItemKindConstant = { fg = "#FFE082", bg = "#D4BB6C" },
  CmpItemKindConstructor = { fg = "#FFE082", bg = "#D4BB6C" },
  CmpItemKindReference = { fg = "#FFE082", bg = "#D4BB6C" },

  CmpItemKindFunction = { fg = "#EADFF0", bg = "#A377BF" },
  CmpItemKindStruct = { fg = "#EADFF0", bg = "#A377BF" },
  CmpItemKindClass = { fg = "#EADFF0", bg = "#A377BF" },
  CmpItemKindModule = { fg = "#EADFF0", bg = "#A377BF" },
  CmpItemKindOperator = { fg = "#EADFF0", bg = "#A377BF" },

  CmpItemKindVariable = { fg = "#C5CDD9", bg = "#7E8294" },
  CmpItemKindFile = { fg = "#C5CDD9", bg = "#7E8294" },

  CmpItemKindUnit = { fg = "#F5EBD9", bg = "#D4A959" },
  CmpItemKindSnippet = { fg = "#F5EBD9", bg = "#D4A959" },
  CmpItemKindFolder = { fg = "#F5EBD9", bg = "#D4A959" },
  CmpItemKindCopilot = { fg = "#F5EBD9", bg = "#D4A959" },

  CmpItemKindMethod = { fg = "#DDE5F5", bg = "#6C8ED4" },
  CmpItemKindValue = { fg = "#DDE5F5", bg = "#6C8ED4" },
  CmpItemKindEnumMember = { fg = "#DDE5F5", bg = "#6C8ED4" },

  CmpItemKindInterface = { fg = "#D8EEEB", bg = "#58B5A8" },
  CmpItemKindColor = { fg = "#D8EEEB", bg = "#58B5A8" },
  CmpItemKindTypeParameter = { fg = "#D8EEEB", bg = "#58B5A8" },

  TSVariable = { link = "Blue" },
  TSConstant = { fg = "#FFE082", bold = true },
  TSKeywordReturn = { bold = true, italic = true },
  TSConstBuiltin = { bold = true, italic = true },
  TSFuncBuiltin = { bold = true, italic = true },
  TSTypeBuiltin = { bold = true, italic = true },
  TSBoolean = { bold = true, italic = true },

  TSType = { bold = true },
  TSConstructor = { bold = true },
  TSOperator = { bold = true },

  TSInclude = { italic = true },
  TSVariableBuiltin = { italic = true },
  TSConditional = { italic = true },
  TSKeyword = { italic = true },
  TSKeywordFunction = { italic = true },
  TSComment = { italic = true },
  TSParameter = { italic = true },
  semshiBuiltin = { italic = true },

  InlayHint = { italic = true },
  LspInlayHint = { italic = true },

  -- lsp semantic token
  ["@repeat"] = { italic = true },
  ["@lsp.type.parameter"] = { link = "aqua" },
  ["@lsp.type.variable"] = { link = "Blue" },
  ["@lsp.type.class"] = { bold = true },
  ["@keyword"] = { italic = true, bold = true },
  ["@keyword.function"] = { bold = true, italic = true },
}

function M.mod_hl(hl_name, opts)
  local is_ok, hl_def = pcall(vim.api.nvim_get_hl, 0, { name = hl_name, link = false })
  if is_ok then
    for k, v in pairs(opts) do
      hl_def[k] = v
    end
    vim.api.nvim_set_hl(0, hl_name, hl_def)
  end
end
-- create a autocommand after colorscheme change
function M.load_syntax()
  for k, v in pairs(M.highlight) do
    M.mod_hl(k, v)
  end
end

vim.api.nvim_create_autocmd({ "VimEnter", "ColorScheme" }, {
  group = vim.api.nvim_create_augroup("Color", {}),
  pattern = "*",
  callback = function()
    require("core.highlight").load_syntax()
  end,
})

return M
