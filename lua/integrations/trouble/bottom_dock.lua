local M = {}

function M.setup()
  local bottom = require("integrations.layout.bottom")
  local bottom_owner_trouble = "trouble_dock"

  local function get_bottom_trouble_views()
    local ok, view = pcall(require, "trouble.view")
    if not ok then
      return {}
    end

    local ret = {}
    for _, entry in ipairs(view.get({ open = true })) do
      local v = entry.view
      if v and v.opts and v.opts.win and v.opts.win.position == "bottom" and v.win and v.win.valid and v.win:valid() then
        ret[#ret + 1] = v
      end
    end
    return ret
  end

  local function hide_trouble_dock()
    for _, v in ipairs(get_bottom_trouble_views()) do
      pcall(function()
        v:close()
      end)
    end
  end

  local function claim_if_bottom(bufnr)
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
      local info = vim.w[win].trouble
      if type(info) == "table" and info.position == "bottom" then
        bottom.toggle({ id = bottom_owner_trouble, hide = hide_trouble_dock, claim = true })
        return
      end
    end
  end

  local group = vim.api.nvim_create_augroup("TroubleBottomDock", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "trouble",
    callback = function(args)
      vim.schedule(function()
        claim_if_bottom(args.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype ~= "trouble" then
        return
      end
      vim.schedule(function()
        claim_if_bottom(args.buf)
      end)
    end,
  })
end

return M
