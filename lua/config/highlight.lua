local M = {}
M.highlight = {
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
