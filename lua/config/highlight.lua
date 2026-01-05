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

  ["@markup.quote.rst"] = { link = "markdownH1" },
  ["@string.special.url.rst"] = { link = { "@markup.link.url", "Grey" } },
  -- lsp semantic token
  -- stylua: ignore start
  ["@repeat"]               = { italic = true },
  ["@lsp.type.parameter"]   = { link   = "aqua" },
  ["@lsp.type.variable"]    = { link   = "Blue" },
  ["@lsp.type.class"]       = { bold   = true },
  ["@keyword"]              = { italic = true, bold   = true },
  ["@keyword.function"]     = { bold   = true, italic = true },
  ["@function.method.call"] = { italic = true },
  -- stylua: ignore end
}

function M.mod_hl(hl_name, opts)
  if type(opts) ~= "table" then
    return
  end
  local link = opts.link
  if type(link) ~= "string" and type(link) ~= "table" then
    return
  end

  local merged = {}
  local function add(name)
    local ok, def = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
    if ok and type(def) == "table" then
      merged = vim.tbl_deep_extend("force", merged, def)
    end
  end

  if type(link) == "string" then
    add(link)
  else
    for _, name in ipairs(link) do
      if type(name) == "string" then
        add(name)
      end
    end
  end

  local extra = vim.deepcopy(opts)
  extra.link = nil

  merged = vim.tbl_deep_extend("force", merged, extra)
  vim.api.nvim_set_hl(0, hl_name, merged)
end

-- create a autocommand after colorscheme change
function M.setup()
  -- print("execute")
  for k, v in pairs(M.highlight) do
    M.mod_hl(k, v)
  end
  -- HACK: this semantic token is overriding the custom sql injection highlight
  vim.api.nvim_set_hl(0, "@lsp.type.string.rust", {})
end

return M
