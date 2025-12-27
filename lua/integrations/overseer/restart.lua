local M = {}

local function get_task_list_win()
  local ok, window = pcall(require, "overseer.window")
  if not ok then
    return nil
  end
  return window.get_win_id()
end

local function get_task_from_tasklist()
  local ok_view, TaskView = pcall(require, "overseer.task_view")
  if ok_view and TaskView.task_under_cursor then
    return TaskView.task_under_cursor
  end
end

local function get_task_from_output()
  local winid = vim.api.nvim_get_current_win()
  local list_win = get_task_list_win()
  if list_win and winid == list_win then
    return nil
  end
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local task_id = vim.b[bufnr].overseer_task
  if not task_id then
    return nil
  end
  local ok_list, task_list = pcall(require, "overseer.task_list")
  if not ok_list then
    return nil
  end
  return task_list.get(task_id)
end

local function restart_task(task)
  if not task then
    return
  end
  local strategy = task.strategy
  if strategy and type(strategy.restart) == "function" then
    local ok, handled = pcall(strategy.restart, strategy, task)
    if ok and handled then
      return
    end
  end
  task:restart(true)
end

function M.from_tasklist()
  restart_task(get_task_from_tasklist())
end

function M.from_output()
  local output_task = get_task_from_output()
  if output_task then
    local ok_window, window = pcall(require, "overseer.window")
    if ok_window then
      window.open({ direction = "bottom", enter = true, focus_task_id = output_task.id })
    end
    local ok_sidebar, sidebar = pcall(require, "overseer.task_list.sidebar")
    if ok_sidebar then
      local sb = sidebar.get_or_create()
      sb:focus_task_id(output_task.id)
    end
    restart_task(get_task_from_tasklist() or output_task)
    return
  end
  local task = get_task_from_tasklist()
  if task then
    local ok_window, window = pcall(require, "overseer.window")
    if ok_window then
      window.open({ direction = "bottom", enter = true, focus_task_id = task.id })
    end
    restart_task(task)
  end
end

return M
