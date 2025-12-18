local M = {}

local uv = vim.uv or vim.loop

local ns = vim.api.nvim_create_namespace("codecompanion_prev_elapsed")

local function format_duration(ms)
  if ms < 1000 then
    return ("%dms"):format(ms)
  end

  local seconds = ms / 1000
  if seconds < 60 then
    return ("%.2fs"):format(seconds)
  end

  local minutes = math.floor(seconds / 60)
  local rem = seconds - (minutes * 60)
  return ("%dm%.1fs"):format(minutes, rem)
end

local function get_bufnr(request)
  if request and type(request) == "table" then
    local bufnr = request.buf
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      return bufnr
    end

    local data_bufnr = request.data and request.data.bufnr
    if data_bufnr and vim.api.nvim_buf_is_valid(data_bufnr) then
      return data_bufnr
    end
  end

  local current = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_is_valid(current) then
    return current
  end
end

local function find_last_me_heading(bufnr)
  local last = vim.api.nvim_buf_line_count(bufnr)
  local start = math.max(0, last - 2000)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, last, false)
  for i = #lines, 1, -1 do
    if lines[i]:match("^##%s*Me%s*$") then
      return start + i - 1
    end
  end
end

local function set_prev_elapsed_virtual_text(bufnr, elapsed_ms)
  local lnum = find_last_me_heading(bufnr)
  if not lnum then
    return
  end

  local text = ("  [prev %s]"):format(format_duration(elapsed_ms))
  vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "eol",
    hl_mode = "combine",
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CodeCompanionPrevElapsed", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatSubmitted",
    callback = function(request)
      local bufnr = get_bufnr(request)
      if not bufnr then
        return
      end

      vim.b[bufnr].codecompanion_chat_submit_hrtime = uv.hrtime()
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatDone",
    callback = function(request)
      local bufnr = get_bufnr(request)
      if not bufnr then
        return
      end

      local start = vim.b[bufnr].codecompanion_chat_submit_hrtime
      if not start then
        return
      end

      local elapsed_ms = math.floor(((uv.hrtime() - start) / 1e6) + 0.5)
      vim.b[bufnr].codecompanion_prev_elapsed_ms = elapsed_ms
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          set_prev_elapsed_virtual_text(bufnr, elapsed_ms)
        end
      end)
    end,
  })
end

return M
