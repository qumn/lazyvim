local M = {}
M.highlight = {
  -- PmenuSel = { bg = "#282C34", fg = "NONE" },
  -- Pmenu = { fg = "#C5CDD9", bg = "#22252A" },
  -- CursorLineNr = { fg = "#e69875", ctermfg = 208, bold = true },
  --
  -- CmpItemAbbrDeprecated = { fg = "#7E8294", strikethrough = true },
  -- BlinkCmpMenuSelection = { fg = "#82AAFF", bold = true },
  -- CmpItemAbbrMatchFuzzy = { fg = "#82AAFF", bold = true },
  -- BlinkCmpMenu = { fg = "#C792EA", italic = true },
  --
  -- BlinkCmpKindField = { fg = "#EED8DA", bg = "#B5585F" },
  -- BlinkCmpKindProperty = { fg = "#EED8DA", bg = "#B5585F" },
  -- BlinkCmpKindEvent = { fg = "#EED8DA", bg = "#B5585F" },
  --
  -- BlinkCmpKindText = { fg = "#C3E88D", bg = "#9FBD73" },
  -- BlinkCmpKindEnum = { fg = "#C3E88D", bg = "#9FBD73" },
  -- BlinkCmpKindKeyword = { fg = "#C3E88D", bg = "#9FBD73" },
  --
  -- BlinkCmpKindConstant = { fg = "#FFE082", bg = "#D4BB6C" },
  -- BlinkCmpKindConstructor = { fg = "#FFE082", bg = "#D4BB6C" },
  -- BlinkCmpKindReference = { fg = "#FFE082", bg = "#D4BB6C" },
  --
  -- BlinkCmpKindFunction = { fg = "#EADFF0", bg = "#A377BF" },
  -- BlinkCmpKindStruct = { fg = "#EADFF0", bg = "#A377BF" },
  -- BlinkCmpKindClass = { fg = "#EADFF0", bg = "#A377BF" },
  -- BlinkCmpKindModule = { fg = "#EADFF0", bg = "#A377BF" },
  -- BlinkCmpKindOperator = { fg = "#EADFF0", bg = "#A377BF" },
  --
  -- BlinkCmpKindVariable = { fg = "#C5CDD9", bg = "#7E8294" },
  -- BlinkCmpKindFile = { fg = "#C5CDD9", bg = "#7E8294" },
  --
  -- BlinkCmpKindUnit = { fg = "#F5EBD9", bg = "#D4A959" },
  -- BlinkCmpKindSnippet = { fg = "#F5EBD9", bg = "#D4A959" },
  -- BlinkCmpKindFolder = { fg = "#F5EBD9", bg = "#D4A959" },
  -- BlinkCmpKindCopilot = { fg = "#F5EBD9", bg = "#D4A959" },
  --
  -- BlinkCmpKindMethod = { fg = "#DDE5F5", bg = "#6C8ED4" },
  -- BlinkCmpKindValue = { fg = "#DDE5F5", bg = "#6C8ED4" },
  -- BlinkCmpKindEnumMember = { fg = "#DDE5F5", bg = "#6C8ED4" },
  --
  -- BlinkCmpKindInterface = { fg = "#D8EEEB", bg = "#58B5A8" },
  -- BlinkCmpKindColor = { fg = "#D8EEEB", bg = "#58B5A8" },
  -- BlinkCmpKindTypeParameter = { fg = "#D8EEEB", bg = "#58B5A8" },

  BlinkCmpLabelDetail = { link = "Grey" },
  BlinkCmpLabelDescription = { link = "Orange" },

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
function M.load()
  -- print("execute")
  for k, v in pairs(M.highlight) do
    M.mod_hl(k, v)
  end
end

M.load()

return M
