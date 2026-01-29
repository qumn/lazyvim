-- Keep ANSI colors in Overseer output while storing clean text in non-terminal buffers.
local M = {}

local function build_script_command(shell, cmd, args)
  if type(cmd) == "string" then
    if args ~= nil then
      local list = { cmd }
      if type(args) == "table" then
        vim.list_extend(list, args)
      else
        table.insert(list, args)
      end
      return shell.escape_cmd(list)
    end
    return cmd
  elseif type(cmd) == "table" then
    local list = vim.deepcopy(cmd)
    if type(args) == "table" then
      vim.list_extend(list, args)
    elseif args ~= nil then
      table.insert(list, args)
    end
    return shell.escape_cmd(list)
  end
end

local function require_executable(cmd, hint)
  if vim.fn.executable(cmd) == 1 then
    return
  end
  if hint and hint ~= "" then
    error(string.format("overseer color_output: `%s` is required (%s)", cmd, hint))
  end
  error(string.format("overseer color_output: `%s` is required", cmd))
end

local function strip_non_sgr_escapes(str)
  if not str or str == "" then
    return str
  end

  local sgr = {}
  str = str:gsub("\27%[[0-9;]*m", function(seq)
    sgr[#sgr + 1] = seq
    return "\1SGR" .. tostring(#sgr) .. "\2"
  end)

  str = str:gsub("\27%][^\7]*\7", "")
  str = str:gsub("\27%][^\27]*\27\\", "")
  str = str:gsub("\27%[[0-9;?]*[@-~]", "")

  str = str:gsub("\1SGR(%d+)\2", function(n)
    return sgr[tonumber(n)] or ""
  end)

  return str
end

local function wrap_with_script(shell, task_defn)
  -- `script` allocates a PTY so CLI tools emit ANSI colors in non-terminal buffers.
  local script_path = vim.fn.exepath("script")
  local cmd = task_defn.cmd
  if not cmd then
    return
  end
  if type(cmd) == "table" and cmd[1] == "script" then
    return
  end
  if type(cmd) == "string" and cmd:match("^%s*script%s") then
    return
  end
  local cmd_str = build_script_command(shell, cmd, task_defn.args)
  if not cmd_str or cmd_str == "" then
    return
  end
  task_defn.cmd = { script_path ~= "" and script_path or "script", "-q", "-e", "-c", cmd_str, "/dev/null" }
  task_defn.args = nil
end

local function ensure_color_env(task)
  if not (task.env and type(task.env) == "table") then
    task.env = {}
  else
    task.env = vim.deepcopy(task.env)
  end
  local env = task.env
  env.TERM = env.TERM or "xterm-256color"
  env.COLORTERM = env.COLORTERM or "truecolor"
  env.FORCE_COLOR = env.FORCE_COLOR or "1"
  env.CLICOLOR_FORCE = env.CLICOLOR_FORCE or "1"
  env.SPRING_OUTPUT_ANSI_ENABLED = env.SPRING_OUTPUT_ANSI_ENABLED or "ALWAYS"
end

local function prepare_task_for_color(self, shell, task)
  if self.opts and self.opts.use_terminal == false then
    if task.cmd and vim.fn.has("linux") == 1 then
      require_executable("script", "install util-linux")
      wrap_with_script(shell, task)
    end
    ensure_color_env(task)
  end
end

local function ensure_buf(self)
  local wrap_term = self.opts.wrap_opts and self.opts.wrap_opts.term
  if wrap_term then
    self.bufnr = vim.api.nvim_get_current_buf()
  end
  if not self.bufnr then
    self:_init_buffer()
  end
  return wrap_term
end

local function make_raw_line_iter(self)
  -- Preserve ANSI across jobstart chunks; pending holds the last unfinished line.
  self._raw_pending = self._raw_pending or ""
  local function raw_line(str)
    return str:gsub("\r$", "")
  end
  local function finalize_line(str)
    return strip_non_sgr_escapes(raw_line(str))
  end
  return function(data)
    local ret = {}
    local pending = self._raw_pending
    for i, chunk in ipairs(data) do
      if i == 1 then
        if chunk == "" then
          table.insert(ret, finalize_line(pending))
          pending = ""
        else
          pending = pending .. raw_line(chunk)
        end
      else
        if not (data[1] == "" and i == 2) then
          table.insert(ret, finalize_line(pending))
        end
        pending = raw_line(chunk)
      end
    end
    self._raw_pending = pending
    return ret
  end
end

local function collect_trailing_wins(bufnr, line_count)
  local trail_wins = {}
  for _, winid in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      if vim.api.nvim_win_get_cursor(winid)[1] == line_count then
        table.insert(trail_wins, winid)
      end
    end
  end
  return trail_wins
end

local function write_baleia_lines(baleia, bufnr, start, end_, raw_lines)
  -- Baleia strips ANSI from text and adds highlights from the raw ANSI stream.
  local modifiable = vim.bo[bufnr].modifiable
  if not modifiable then
    vim.bo[bufnr].modifiable = true
  end

  baleia.buf_set_lines(bufnr, start, end_, true, raw_lines)
  vim.bo[bufnr].modified = false

  if not modifiable then
    vim.bo[bufnr].modifiable = false
  end
end

local function update_trailing_cursors(util_mod, trail_wins, lnum, raw_line)
  local last_clean = util_mod.remove_ansi(raw_line)
  local col = vim.api.nvim_strwidth(last_clean)
  for _, winid in ipairs(trail_wins) do
    vim.api.nvim_win_set_cursor(winid, { lnum, col })
  end
end

local function append_exit_line(baleia, bufnr, code)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  write_baleia_lines(baleia, bufnr, line_count, line_count, { string.format("[Process exited %d]", code), "" })
end

local function attach_baleia_autocmd()
  local baleia_group = vim.api.nvim_create_augroup("OverseerOutputBaleia", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = baleia_group,
    pattern = "OverseerOutput",
    callback = function(args)
      for _, lhs in ipairs({ "i", "I", "a", "A", "o", "O" }) do
        pcall(vim.keymap.del, "n", lhs, { buffer = args.buf })
      end
    end,
  })
end

local function patch_jobstart(baleia, shell)
  local jobstart = require("overseer.strategy.jobstart")
  if jobstart._script_wrapper_patched then
    return
  end
  jobstart._script_wrapper_patched = true

  local orig_start = jobstart.start
  local upvals = {}
  local i = 1
  while true do
    local name, val = debug.getupvalue(orig_start, i)
    if not name then
      break
    end
    upvals[name] = val
    i = i + 1
  end
  local log = upvals.log or require("overseer.log")
  local register = upvals.register
  local unregister = upvals.unregister
  local util_mod = upvals.util or require("overseer.util")
  local overseer_mod = upvals.overseer or require("overseer")

  jobstart.start = function(self, task)
    prepare_task_for_color(self, shell, task)
    local wrap_term = ensure_buf(self)
    local wrap = self.opts.wrap_opts or {}

    local stdout_iter = util_mod.get_stdout_line_iter()
    local raw_line_iter = make_raw_line_iter(self)

    local function on_stdout(data)
      if wrap_term then
        -- don't do anything
      elseif self.opts.use_terminal then
        if self.term_id then
          pcall(vim.api.nvim_chan_send, self.term_id, table.concat(data, "\r\n"))
          vim.defer_fn(function()
            util_mod.terminal_tail_hack(self.bufnr)
          end, 10)
        else
          table.insert(self.pending_output, data)
        end
      else
        local line_count = vim.api.nvim_buf_line_count(self.bufnr)
        local trail_wins = collect_trailing_wins(self.bufnr, line_count)
        local raw_lines = raw_line_iter(data)
        raw_lines[#raw_lines + 1] = strip_non_sgr_escapes(self._raw_pending)
        local start = math.max(line_count - 1, 0)
        write_baleia_lines(baleia, self.bufnr, start, line_count, raw_lines)

        local lnum = line_count + #raw_lines - 1
        update_trailing_cursors(util_mod, trail_wins, lnum, raw_lines[#raw_lines])
      end

      task:dispatch("on_output", data)
      local lines = stdout_iter(data)
      if not vim.tbl_isempty(lines) then
        task:dispatch("on_output_lines", lines)
      end
    end

    local function coalesce(a, b)
      if a == nil then
        return b
      else
        return a
      end
    end

    local opts = vim.tbl_extend("force", wrap, {
      cwd = task.cwd,
      env = task.env,
      pty = coalesce(wrap.pty, self.opts.use_terminal),
      width = coalesce(wrap.width, vim.o.columns - 4),
      on_stdout = function(j, d, m)
        if wrap.on_stdout then
          wrap.on_stdout(j, d, m)
        end
        if self.job_id ~= j then
          return
        end
        on_stdout(d)
      end,
      on_stderr = function(j, d, m)
        if wrap.on_stderr then
          wrap.on_stderr(j, d, m)
        end
        if self.job_id ~= j then
          return
        end
        on_stdout(d)
      end,
      on_exit = function(j, c, m)
        if wrap.on_exit then
          wrap.on_exit(j, c, m)
        end
        if unregister then
          unregister(j)
        end
        if self.job_id ~= j then
          return
        end
        log.debug("Task %s exited with code %s", task.name, c)
        on_stdout({ "" })
        if self.opts.use_terminal then
          if self.term_id then
            pcall(vim.api.nvim_chan_send, self.term_id, string.format("\r\n[Process exited %d]\r\n", c))
            vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback - 1
            vim.bo[self.bufnr].scrollback = vim.bo[self.bufnr].scrollback + 1
            util_mod.terminal_tail_hack(self.bufnr)
          else
            table.insert(self.pending_output, { "", string.format("[Process exited %d]", c), "" })
          end
        else
          append_exit_line(baleia, self.bufnr, c)
        end
        self.job_id = nil
        if vim.v.exiting == vim.NIL then
          task:on_exit(c)
        end
      end,
    })

    self.job_id = overseer_mod.builtin.jobstart(task.cmd, opts)

    if self.job_id == 0 then
      log.error("Invalid arguments for task '%s'", task.name)
    elseif self.job_id == -1 then
      log.error("Command '%s' not executable", task.cmd)
    else
      if register then
        register(self.job_id)
      end
    end
  end
end

function M.setup()
  if not package.loaded["baleia"] then
    require("lazy").load({ plugins = { "baleia.nvim" } })
  end
  local baleia = require("baleia").setup({ strip_ansi_codes = true })
  local shell = require("overseer.shell")

  attach_baleia_autocmd()
  patch_jobstart(baleia, shell)
end

return M
