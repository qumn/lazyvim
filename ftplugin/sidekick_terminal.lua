if vim.bo.filetype ~= "sidekick_terminal" or vim.b.did_sidekick_terminal_ftplugin then
  return
end
vim.b.did_sidekick_terminal_ftplugin = true

local SYNTAX = {
  dash_tokens = { "-", "－", "–", "—" },
  loc_tokens = { ":", "#", "：" },
  trailing_punct_pat = "[,，。；;、]+$",
  lua = {
    file_only_pats = {
      "^/[%w%._%-%/]+%.[%w_]+$",
      "^@[%w%._%-%/]+%.[%w_]+$",
      "^[%w%._%-]+/[%w%._%-%/]*%.[%w_]+$",
    },
    file_ref_pats = {
      "(@?[%w%._%-%/]+%.[%w_]+)%s*[:#]%s*[Ll]?(%d+)",
      "(@?[%w%._%-%/]+%.[%w_]+)%s*：%s*[Ll]?(%d+)",
    },
    cfile_ref_pats = {
      "^(.+)%s*[:#]%s*[Ll]?(%d+)",
      "^(.+)%s*：%s*[Ll]?(%d+)",
    },
    file_token_pats = {
      "(/[%w%._%-%/]+%.[%w_]+)",
      "(@[%w%._%-%/]+%.[%w_]+)",
      "([%w%._%-]+/[%w%._%-%/]*%.[%w_]+)",
    },
  },
  vim = {
    path = [=[@\?/\?\%([[:alnum:]_.…-]\+/\)\+[[:alnum:]_.…-]\+\.[[:alpha:]][[:alnum:]_]*]=],
  },
}

local function vim_charclass(tokens)
  local ordered = {}
  for _, tok in ipairs(tokens) do
    if tok == "-" then
      table.insert(ordered, 1, tok)
    else
      table.insert(ordered, tok)
    end
  end
  return "[" .. table.concat(ordered) .. "]"
end

do
  local vim_loc = vim_charclass(SYNTAX.loc_tokens)
  local vim_dash = vim_charclass(SYNTAX.dash_tokens)
  SYNTAX.vim.loc = [=[\s*]=] .. vim_loc .. [=[\s*[Ll]\?\d\+]=]
  SYNTAX.vim.range = [=[\%(\s*]=] .. vim_dash .. [=[\s*]=] .. vim_loc .. [=[\?\s*[Ll]\?\d\+\)\?]=]
  SYNTAX.vim.path_with_loc = SYNTAX.vim.path .. SYNTAX.vim.loc .. SYNTAX.vim.range
end

local function rstrip_punct(s)
  return (s:gsub(SYNTAX.trailing_punct_pat, ""))
end

local function looks_like_file(s)
  if type(s) ~= "string" or s == "" then
    return false
  end

  s = vim.trim(rstrip_punct(s))
  for _, pat in ipairs(SYNTAX.lua.file_only_pats) do
    if s:match(pat) then
      return true
    end
  end
  return false
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

local joinpath = vim.fs.joinpath or function(...)
  return table.concat({ ... }, "/")
end

local normalize = vim.fs.normalize or function(p)
  return p
end

local function parse_path_line()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  local file_matches = {}

  local function skip_ws(idx)
    while true do
      local c = line:sub(idx, idx)
      if c == " " or c == "\t" then
        idx = idx + 1
      else
        break
      end
    end
    return idx
  end

  local function take_any(idx, tokens)
    for _, tok in ipairs(tokens) do
      if line:sub(idx, idx + #tok - 1) == tok then
        return idx + #tok
      end
    end
  end

  local function take_dash(idx)
    return take_any(idx, SYNTAX.dash_tokens)
  end

  local function take_loc(idx)
    return take_any(idx, SYNTAX.loc_tokens)
  end

  local function range_suffix(idx)
    idx = skip_ws(idx)
    local next_idx = take_dash(idx)
    if not next_idx then
      return
    end

    idx = skip_ws(next_idx)
    idx = take_loc(idx) or idx

    idx = skip_ws(idx)
    local l = line:sub(idx, idx)
    if l == "L" or l == "l" then
      idx = idx + 1
    end

    local ds, de = line:find("%d+", idx)
    if not ds or not de or ds ~= idx then
      return
    end

    local end_lnum = tonumber(line:sub(ds, de))
    if not end_lnum then
      return
    end

    return end_lnum, de + 1
  end

  local function add_file_matches(pat)
    for s, f, n, e in line:gmatch("()" .. pat .. "()") do
      local end_lnum, end_pos = range_suffix(e)
      if end_lnum and end_pos then
        e = end_pos
      end
      table.insert(file_matches, { s = s, e = e, file = rstrip_punct(f), lnum = tonumber(n), end_lnum = end_lnum })
    end
  end

  for _, pat in ipairs(SYNTAX.lua.file_ref_pats) do
    add_file_matches(pat)
  end

  table.sort(file_matches, function(a, b)
    return a.s < b.s
  end)

  for _, m in ipairs(file_matches) do
    if col >= m.s and col <= m.e then
      return m.file, m.lnum, m.end_lnum
    end
  end

  local function plain_file_under_cursor()
    local matches = {}

    for _, pat in ipairs(SYNTAX.lua.file_token_pats) do
      for s, f, e in line:gmatch("()" .. pat .. "()") do
        table.insert(matches, { s = s, e = e, file = rstrip_punct(f) })
      end
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
    for _, pat in ipairs(SYNTAX.lua.cfile_ref_pats) do
      local f, n = cfile:match(pat)
      if f and n and looks_like_file(f) then
        return vim.trim(rstrip_punct(f)), tonumber(n)
      end
    end

    local f4 = rstrip_punct(cfile)
    for _, pat in ipairs(SYNTAX.lua.file_only_pats) do
      if f4:match(pat) then
        return f4
      end
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

local function resolve_full_path(file, root, uv, prev_line)
  if vim.startswith(file, "@") then
    return normalize(joinpath(root, file:sub(2)))
  end
  if vim.startswith(file, "/") then
    return normalize(file)
  end

  local full = normalize(joinpath(root, file))
  if uv.fs_stat(full) then
    return full
  end

  if type(prev_line) ~= "string" or prev_line == "" then
    return full
  end

  local prefix = rstrip_punct(prev_line):match("(@?[%w%._%-%/]+/)%s*$")
  if not prefix then
    return full
  end

  local alt
  if vim.startswith(prefix, "@") then
    alt = normalize(joinpath(root, prefix:sub(2), file))
  elseif vim.startswith(prefix, "/") then
    alt = normalize(joinpath(prefix, file))
  else
    alt = normalize(joinpath(root, prefix, file))
  end

  if alt and uv.fs_stat(alt) then
    return alt
  end

  return full
end

local function goto_location(lnum, end_lnum)
  if not lnum or lnum <= 0 then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  local function clamp(n)
    return math.max(1, math.min(n, line_count))
  end

  if end_lnum and end_lnum > 0 then
    local start = clamp(lnum)
    local finish = clamp(end_lnum)
    if finish < start then
      start, finish = finish, start
    end

    vim.api.nvim_win_set_cursor(0, { start, 0 })
    vim.cmd.normal({ "V" .. finish .. "G", bang = true })
  else
    vim.api.nvim_win_set_cursor(0, { clamp(lnum), 0 })
  end

  vim.cmd.normal({ "zz", bang = true })
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

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local prev_line
  if row > 1 then
    prev_line = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  end

  local full = resolve_full_path(file, root, uv, prev_line)

  local stat = uv.fs_stat(full)
  if not stat or stat.type == "directory" then
    vim.notify(("file not found: %s"):format(full), vim.log.levels.WARN)
    return
  end

  local target_win = pick_target_win(source_win)
  vim.api.nvim_set_current_win(target_win)

  vim.cmd.edit(vim.fn.fnameescape(full))
  goto_location(lnum, end_lnum)
end

vim.keymap.set("n", "gd", jump, { buffer = true, silent = true })

vim.api.nvim_set_hl(0, "SidekickPath", { underline = true, default = true })

local function clear_sidekick_path_matches(win)
  for _, m in ipairs(vim.fn.getmatches(win)) do
    if m.group == "SidekickPath" then
      pcall(vim.fn.matchdelete, m.id, win)
    end
  end
end

local function add_path_matches()
  local win = vim.api.nvim_get_current_win()
  clear_sidekick_path_matches(win)

  vim.fn.matchadd("SidekickPath", SYNTAX.vim.path_with_loc, 1000, -1, { window = win })
  vim.fn.matchadd("SidekickPath", SYNTAX.vim.path, 1000, -1, { window = win })
end

local function clear_path_matches()
  local win = vim.api.nvim_get_current_win()
  clear_sidekick_path_matches(win)
end

add_path_matches()

local group = vim.api.nvim_create_augroup("SidekickTerminalPathMatches", { clear = false })
vim.api.nvim_clear_autocmds({ group = group, buffer = 0 })
vim.api.nvim_create_autocmd("BufWinEnter", { group = group, buffer = 0, callback = add_path_matches })
vim.api.nvim_create_autocmd("BufWinLeave", { group = group, buffer = 0, callback = clear_path_matches })
