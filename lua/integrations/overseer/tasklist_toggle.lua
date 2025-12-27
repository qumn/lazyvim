local M = {}

local function get_task_list_win()
  local ok, window = pcall(require, "overseer.window")
  if not ok then
    return nil
  end
  return window.get_win_id()
end

local function get_state(winid)
  local state = vim.w[winid].overseer_tasklist_toggle
  if type(state) ~= "table" then
    state = { hidden = false, width = nil }
  end
  return state
end

local function save_state(winid, state)
  vim.w[winid].overseer_tasklist_toggle = state
end

local function restore_width(winid, state)
  local width = state.width
  if not width or width < 2 then
    local ok_layout, layout = pcall(require, "overseer.layout")
    local ok_config, config = pcall(require, "overseer.config")
    if ok_layout and ok_config then
      width = layout.calculate_width(nil, config.task_list)
    end
  end
  if width and width > 1 then
    pcall(vim.api.nvim_win_set_width, winid, width)
  end
  state.hidden = false
  save_state(winid, state)
end

local function hide_list(winid, state)
  state.width = vim.api.nvim_win_get_width(winid)
  state.hidden = true
  save_state(winid, state)
  pcall(vim.api.nvim_win_set_width, winid, 1)
end

local function find_output_win(task_id)
  if not task_id then
    task_id = nil
  end
  local fallback
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) then
      local bufnr = vim.api.nvim_win_get_buf(winid)
      if vim.bo[bufnr].filetype ~= "OverseerList" and vim.b[bufnr].overseer_task ~= nil then
        if task_id and vim.b[bufnr].overseer_task == task_id then
          return winid
        end
        fallback = fallback or winid
      end
    end
  end
  return fallback
end

function M.toggle_from_tasklist()
  local list_win = get_task_list_win()
  if not list_win or not vim.api.nvim_win_is_valid(list_win) then
    return
  end
  local state = get_state(list_win)
  if state.hidden then
    restore_width(list_win, state)
    return
  end

  local task_id
  local ok_sidebar, sidebar = pcall(require, "overseer.task_list.sidebar")
  if ok_sidebar then
    local sb = sidebar.get()
    if sb then
      local task = sb:get_task_from_line()
      task_id = task and task.id or nil
    end
  end

  hide_list(list_win, state)

  local output_win = find_output_win(task_id)
  if output_win then
    vim.api.nvim_set_current_win(output_win)
  end
end

function M.toggle_from_output()
  local list_win = get_task_list_win()
  if not list_win or not vim.api.nvim_win_is_valid(list_win) then
    return
  end
  local state = get_state(list_win)
  if state.hidden then
    restore_width(list_win, state)
    local task_id = vim.b[vim.api.nvim_get_current_buf()].overseer_task
    local ok_sidebar, sidebar = pcall(require, "overseer.task_list.sidebar")
    if ok_sidebar then
      local sb = sidebar.get_or_create()
      if task_id then
        sb:focus_task_id(task_id)
      end
    end
    vim.api.nvim_set_current_win(list_win)
  else
    hide_list(list_win, state)
  end
end

return M
