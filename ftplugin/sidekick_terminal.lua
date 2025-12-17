local function rstrip_punct(s)
  return (s:gsub("[,，。；;、]+$", ""))
end

local function project_root()
  if _G.LazyVim and _G.LazyVim.root then
    local ok, root = pcall(function()
      return (_G.LazyVim.root.get and _G.LazyVim.root.get()) or _G.LazyVim.root()
    end)
    if ok and type(root) == "string" and root ~= "" then
      return root
    end
  end

  local git_dir = vim.fs.find(".git", { upward = true, type = "directory" })[1]
  if git_dir then
    return vim.fs.dirname(git_dir)
  end

  return (vim.uv or vim.loop).cwd()
end

local function parse_path_line()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  local file_num_pat = "(@?[%w%._%-%/]+%.[%w_]+)%s*:%s*(%d+)"
  local file_l_pat = "(@?[%w%._%-%/]+%.[%w_]+)%s*[:#]%s*[Ll](%d+)"
  local bare_num_pat = ":%s*(%d+)"
  local bare_l_pat = ":%s*[Ll](%d+)"

  local file_matches = {}

  for s, f, n, e in line:gmatch("()" .. file_num_pat .. "()") do
    table.insert(file_matches, { s = s, e = e, file = rstrip_punct(f), lnum = tonumber(n) })
  end
  for s, f, n, e in line:gmatch("()" .. file_l_pat .. "()") do
    local rs, re = line:find("%s*%-%s*[Ll]%d+", e)
    local end_lnum
    if rs == e then
      end_lnum = tonumber(line:match("%s*%-%s*[Ll](%d+)", e))
      e = re + 1
    end
    table.insert(file_matches, { s = s, e = e, file = rstrip_punct(f), lnum = tonumber(n), end_lnum = end_lnum })
  end

  table.sort(file_matches, function(a, b)
    return a.s < b.s
  end)

  for _, m in ipairs(file_matches) do
    if col >= m.s and col <= m.e then
      return m.file, m.lnum, m.end_lnum
    end
  end

  local function file_before(pos)
    local best
    for _, m in ipairs(file_matches) do
      if m.s < pos then
        best = m.file
      else
        break
      end
    end
    return best
  end

  for s, n, e in line:gmatch("()" .. bare_num_pat .. "()") do
    if col >= s and col <= e then
      local f = file_before(s)
      if f then
        return f, tonumber(n)
      end
      break
    end
  end

  for s, n, e in line:gmatch("()" .. bare_l_pat .. "()") do
    local rs, re = line:find("%s*%-%s*[Ll]%d+", e)
    local end_lnum
    if rs == e then
      end_lnum = tonumber(line:match("%s*%-%s*[Ll](%d+)", e))
      e = re + 1
    end
    if col >= s and col <= e then
      local f = file_before(s)
      if f then
        return f, tonumber(n), end_lnum
      end
      break
    end
  end

  local function plain_file_under_cursor()
    local matches = {}
    local abs_pat = "(/[%w%._%-%/]+%.[%w_]+)"
    local at_pat = "(@[%w%._%-%/]+%.[%w_]+)"
    local rel_pat = "([%w%._%-]+/[%w%._%-%/]*%.[%w_]+)"

    for s, f, e in line:gmatch("()" .. abs_pat .. "()") do
      table.insert(matches, { s = s, e = e, file = rstrip_punct(f) })
    end
    for s, f, e in line:gmatch("()" .. at_pat .. "()") do
      table.insert(matches, { s = s, e = e, file = rstrip_punct(f) })
    end
    for s, f, e in line:gmatch("()" .. rel_pat .. "()") do
      table.insert(matches, { s = s, e = e, file = rstrip_punct(f) })
    end

    table.sort(matches, function(a, b)
      return a.s < b.s
    end)

    for _, m in ipairs(matches) do
      if col >= m.s and col <= m.e then
        return m.file
      end
    end
  end

  local plain_file = plain_file_under_cursor()
  if plain_file then
    return plain_file
  end

  local cfile = vim.fn.expand("<cfile>")
  if cfile and cfile ~= "" then
    local f2, n2 = cfile:match("^(.+)%s*:%s*(%d+)$")
    if f2 and n2 then
      return rstrip_punct(f2), tonumber(n2)
    end

    local f3, n3 = cfile:match("^(.+)%s*[:#]%s*[Ll](%d+)")
    if f3 and n3 then
      return rstrip_punct(f3), tonumber(n3)
    end

    local f4 = rstrip_punct(cfile)
    if f4:match("^/[%w%._%-%/]+%.[%w_]+$") or f4:match("^@[%w%._%-%/]+%.[%w_]+$") or f4:match("^[%w%._%-]+/[%w%._%-%/]*%.[%w_]+$") then
      return f4
    end
  end
end

local function pick_target_win(source_win)
  local alt = vim.fn.win_getid(vim.fn.winnr("#"))
  if alt ~= 0 and alt ~= source_win then
    return alt
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= source_win then
      return win
    end
  end

  vim.cmd.vsplit()
  return vim.api.nvim_get_current_win()
end

local function jump()
  local source_win = vim.api.nvim_get_current_win()
  local file, lnum, end_lnum = parse_path_line()
  if not file then
    vim.notify("no path:line under cursor", vim.log.levels.WARN)
    return
  end

  local uv = vim.uv or vim.loop
  local root = project_root()

  local full
  if vim.startswith(file, "@") then
    full = root .. "/" .. file:sub(2)
  elseif vim.startswith(file, "/") then
    full = file
  else
    full = root .. "/" .. file
    if not uv.fs_stat(full) then
      local row = vim.api.nvim_win_get_cursor(0)[1]
      local prev = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
      if prev and prev ~= "" then
        local prefix = rstrip_punct(prev):match("(@?[%w%._%-%/]+/)%s*$")
        if prefix then
          local alt
          if vim.startswith(prefix, "@") then
            alt = root .. "/" .. prefix:sub(2) .. file
          elseif vim.startswith(prefix, "/") then
            alt = prefix .. file
          else
            alt = root .. "/" .. prefix .. file
          end

          if uv.fs_stat(alt) then
            full = alt
          end
        end
      end
    end
  end

  local target_win = pick_target_win(source_win)
  vim.api.nvim_set_current_win(target_win)

  vim.cmd.edit(vim.fn.fnameescape(full))
  if lnum and lnum > 0 then
    local line_count = vim.api.nvim_buf_line_count(0)
    if end_lnum and end_lnum > 0 then
      local start = lnum
      local finish = end_lnum
      if finish < start then
        start, finish = finish, start
      end

      start = math.max(1, math.min(start, line_count))
      finish = math.max(1, math.min(finish, line_count))
      if finish < start then
        start, finish = finish, start
      end

      vim.api.nvim_win_set_cursor(0, { start, 0 })
      vim.cmd.normal({ "V" .. finish .. "G", bang = true })
      vim.cmd.normal({ "zz", bang = true })
    else
      local target = math.max(1, math.min(lnum, line_count))
      vim.api.nvim_win_set_cursor(0, { target, 0 })
      vim.cmd.normal({ "zz", bang = true })
    end
  end
end

vim.keymap.set("n", "gd", jump, { buffer = true, silent = true })

vim.api.nvim_set_hl(0, "SidekickPath", { underline = true })

local function add_path_matches()
  if vim.w.sidekick_terminal_path_matches then
    return
  end

  local win = vim.api.nvim_get_current_win()
  vim.w.sidekick_terminal_path_matches = true
  vim.w.sidekick_terminal_path_match_ids = {
    vim.fn.matchadd("SidekickPath", [[\v\%x40?[\w\.\-_\/]+\.\w+\s*:\s*\d+]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v\%x40?[\w\.\-_\/]+\.\w+\s*[:#]\s*L\d+(\s*-\s*L\d+)?]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v\/[\w\.\-_\/]+\.\w+]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v\%x40[\w\.\-_\/]+\.\w+]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v[\w\.\-_]+\/[\w\.\-_\/]+\.\w+]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v:\s*\d+]], 200, -1, { window = win }),
    vim.fn.matchadd("SidekickPath", [[\v:\s*L\d+(\s*-\s*L\d+)?]], 200, -1, { window = win }),
  }
end

local function clear_path_matches()
  local win = vim.api.nvim_get_current_win()
  local ids = vim.w.sidekick_terminal_path_match_ids
  if type(ids) == "table" then
    for _, id in ipairs(ids) do
      pcall(vim.fn.matchdelete, id, win)
    end
  end

  vim.w.sidekick_terminal_path_matches = nil
  vim.w.sidekick_terminal_path_match_ids = nil
end

add_path_matches()

local group = vim.api.nvim_create_augroup("SidekickTerminalPathMatches", { clear = false })
vim.api.nvim_clear_autocmds({ group = group, buffer = 0 })
vim.api.nvim_create_autocmd("BufWinEnter", { group = group, buffer = 0, callback = add_path_matches })
vim.api.nvim_create_autocmd("BufWinLeave", { group = group, buffer = 0, callback = clear_path_matches })
