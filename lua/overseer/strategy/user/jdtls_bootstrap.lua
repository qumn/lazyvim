local M = {}

local function list_clients()
  local get_clients = vim.lsp.get_clients
  if type(get_clients) == "function" then
    return get_clients()
  end
  return {}
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  if path:match("^file://") then
    path = vim.uri_to_fname(path)
  end

  local expanded = vim.fn.expand(path)
  local real = (vim.uv or vim.loop).fs_realpath(expanded) or vim.fn.fnamemodify(expanded, ":p")
  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(real)
  end
  return real
end

local function client_root_dir(client)
  local cfg = client and client.config or nil
  if cfg and type(cfg.root_dir) == "string" and cfg.root_dir ~= "" then
    return cfg.root_dir
  end
  if client and type(client.root_dir) == "string" and client.root_dir ~= "" then
    return client.root_dir
  end
  local wf = client and client.workspace_folders or nil
  if type(wf) == "table" and wf[1] then
    if type(wf[1].uri) == "string" and wf[1].uri ~= "" then
      return wf[1].uri
    end
    if type(wf[1].name) == "string" and wf[1].name ~= "" then
      return wf[1].name
    end
  end
  return nil
end

local function client_matches_root(client, root_dir)
  local want = normalize_path(root_dir)
  if not want then
    return true
  end
  local have = normalize_path(client_root_dir(client))
  if not have then
    return false
  end
  return have == want
end

function M.find_jdtls_client(bufnr, preferred_id, root_dir)
  local want = normalize_path(root_dir)
  if preferred_id then
    local c = vim.lsp.get_client_by_id(preferred_id)
    if c and c.name == "jdtls" and client_matches_root(c, want) then
      return c
    end
  end

  if bufnr and bufnr > 0 then
    for _, c in ipairs(list_clients()) do
      if c.name == "jdtls" and c.attached_buffers and c.attached_buffers[bufnr] then
        if client_matches_root(c, want) then
          return c
        end
      end
    end
  end

  for _, c in ipairs(list_clients()) do
    if c.name == "jdtls" and client_matches_root(c, want) then
      return c
    end
  end

  if want then
    for _, c in ipairs(list_clients()) do
      if c.name == "jdtls" then
        return c
      end
    end
  end

  return nil
end

local function create_bootstrap_buf(root_dir)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false

  local name
  if type(root_dir) == "string" and root_dir ~= "" then
    if vim.fs and vim.fs.joinpath then
      name = vim.fs.joinpath(root_dir, ".jdtls_bootstrap.java")
    else
      name = root_dir .. "/.jdtls_bootstrap.java"
    end
  else
    name = ".jdtls_bootstrap.java"
  end

  pcall(vim.api.nvim_buf_set_name, bufnr, name)

  return bufnr
end

function M.ensure_jdtls_started(opts)
  opts = opts or {}
  local root_dir = opts.root_dir

  if M.find_jdtls_client(opts.bufnr, opts.client_id, root_dir) then
    return true
  end

  local bufnr = create_bootstrap_buf(root_dir)

  vim.api.nvim_buf_call(bufnr, function()
    vim.bo.filetype = "java"

    pcall(require, "jdtls")

    pcall(vim.api.nvim_exec_autocmds, "FileType", {
      buffer = bufnr,
      pattern = "java",
      modeline = false,
    })
  end)

  return true
end

function M.pick_request_bufnr(client, preferred_bufnr)
  if preferred_bufnr and preferred_bufnr > 0 and client and client.attached_buffers and client.attached_buffers[preferred_bufnr] then
    return preferred_bufnr
  end
  if client and client.attached_buffers then
    for bufnr, attached in pairs(client.attached_buffers) do
      if attached and vim.api.nvim_buf_is_valid(bufnr) then
        return bufnr
      end
    end
  end
  return preferred_bufnr
end

return M
