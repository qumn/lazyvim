if vim.g.loaded_spring_nvim then
  return
end
vim.g.loaded_spring_nvim = true

-- User command: :SpringEndpoints
vim.api.nvim_create_user_command("SpringEndpoints", function()
  local ok_telescope, telescope = pcall(require, "telescope")
  if not ok_telescope then
    vim.notify("telescope.nvim is required for SpringEndpoints", vim.log.levels.ERROR)
    return
  end

  -- extension is loaded by lazy spec; this just calls it
  telescope.extensions.spring.endpoints({})
end, {
  desc = "Spring Endpoints (Telescope)",
})
