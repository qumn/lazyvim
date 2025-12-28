local M = {}

local function get_upvalue(fn, name)
  for i = 1, 20 do
    local up_name, value = debug.getupvalue(fn, i)
    if not up_name then
      return nil
    end
    if up_name == name then
      return value, i
    end
  end
end

local function set_upvalue(fn, name, value)
  for i = 1, 20 do
    local up_name = debug.getupvalue(fn, i)
    if not up_name then
      return false
    end
    if up_name == name then
      debug.setupvalue(fn, i, value)
      return true
    end
  end
  return false
end

local function patch_jobstart(wait_ms)
  local ok, JobstartStrategy = pcall(require, "overseer.strategy.jobstart")
  if not ok or type(JobstartStrategy.start) ~= "function" then
    return
  end
  local register = get_upvalue(JobstartStrategy.start, "register")
  if type(register) ~= "function" then
    return
  end
  local cleanup_autocmd = get_upvalue(register, "cleanup_autocmd")
  local all_channels = get_upvalue(register, "all_channels")
  local log = get_upvalue(register, "log")
  if type(all_channels) ~= "table" then
    return
  end
  if cleanup_autocmd then
    pcall(vim.api.nvim_del_autocmd, cleanup_autocmd)
  end
  local autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
    desc = "Clean up running overseer tasks on exit",
    callback = function()
      local job_ids = vim.tbl_keys(all_channels)
      if #job_ids == 0 then
        return
      end
      if log and log.debug then
        log.debug("VimLeavePre clean up terminal tasks %s", job_ids)
      end
      if wait_ms == 0 then
        for _, chan_id in ipairs(job_ids) do
          local pid = vim.fn.jobpid(chan_id)
          if pid and pid > 0 then
            pcall(vim.uv.kill, pid, "sigterm")
          end
        end
        return
      end
      for _, chan_id in ipairs(job_ids) do
        vim.fn.jobstop(chan_id)
      end
      local start_wait = vim.uv.hrtime()
      vim.fn.jobwait(job_ids, wait_ms)
      local elapsed = (vim.uv.hrtime() - start_wait) / 1e6
      if elapsed > 1000 and log and log.warn then
        log.warn(
          "Killing running tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
          elapsed
        )
      end
    end,
  })
  set_upvalue(register, "cleanup_autocmd", autocmd)
end

local function patch_system(wait_ms)
  local ok, SystemStrategy = pcall(require, "overseer.strategy.system")
  if not ok or type(SystemStrategy.start) ~= "function" then
    return
  end
  local register = get_upvalue(SystemStrategy.start, "register")
  if type(register) ~= "function" then
    return
  end
  local cleanup_autocmd = get_upvalue(register, "cleanup_autocmd")
  local all_procs = get_upvalue(register, "all_procs")
  local graceful_kill = get_upvalue(register, "graceful_kill")
  local log = get_upvalue(register, "log")
  if type(all_procs) ~= "table" or type(graceful_kill) ~= "function" then
    return
  end
  if cleanup_autocmd then
    pcall(vim.api.nvim_del_autocmd, cleanup_autocmd)
  end
  local autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
    desc = "Clean up running overseer tasks on exit",
    callback = function()
      if #all_procs == 0 then
        return
      end
      if log and log.debug then
        log.debug("VimLeavePre clean up %d vim.system processes", #all_procs)
      end
      if wait_ms == 0 then
        for _, proc in ipairs(all_procs) do
          proc:kill("SIGTERM")
        end
        return
      end
      for _, proc in ipairs(all_procs) do
        graceful_kill(proc)
      end
      local start_wait = vim.uv.now()
      vim.wait(wait_ms, function()
        return #all_procs == 0
      end)
      local elapsed = (vim.uv.now() - start_wait)
      if elapsed > 1000 and log and log.warn then
        log.warn(
          "Killing running vim.system tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
          elapsed
        )
      end
    end,
  })
  set_upvalue(register, "cleanup_autocmd", autocmd)
end

function M.setup()
  local wait_ms = tonumber(vim.g.overseer_exit_wait_ms)
  if wait_ms == nil then
    wait_ms = 1000
  elseif wait_ms < 0 then
    wait_ms = 0
  end
  patch_jobstart(wait_ms)
  patch_system(wait_ms)
end

return M
