_G.Timeit = function(target, opts)
  opts = opts or {}
  local label = opts.label or "Timeit"

  local start = vim.loop.hrtime()

  if type(target) == "string" then
    vim.cmd(target)
  elseif type(target) == "function" then
    target()
  else
    error("timeit: target must be command string or function")
  end

  local elapsed = (vim.loop.hrtime() - start) / 1e6
  vim.notify(string.format("%s: %.2f ms", label, elapsed), vim.log.levels.INFO)

  return elapsed
end
