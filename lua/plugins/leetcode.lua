local function hl_hex(name, key)
  -- Neovim 0.9+ 用 nvim_get_hl；0.8 用 nvim_get_hl_by_name
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok then
    return nil
  end

  local val = hl[key]
  if not val then
    return nil
  end
  return string.format("#%06x", val)
end

return {
  {
    "kawre/leetcode.nvim",
    cmd = "Leet",
    -- build = ":TSUpdate html", -- if you have `nvim-treesitter` installed
    dependencies = {
      -- include a picker of your choice, see picker section for more details
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      lang = "rust",
      cn = {
        enabled = true,
        translator = true,
        translate_problems = true,
      },
      theme = {
        -- ["alt"] = {
        --   bg = hl_hex("Normal", "bg") or "#FFFFFF",
        -- },
        ["normal"] = {
          fg = hl_hex("Normal", "fg") or "#EA4AAA",
        },
      },
      injector = {
        ["rust"] = {
          before = { "#[allow(dead_code)]", "fn main(){}", "#[allow(dead_code)]", "struct Solution;" },
        },
      },
      keys = {
        focus_testcases = "<C-y>",
        focus_result = "<C-o>",
      },
      hooks = {
        ["question_enter"] = {
          function(question)
            if question.lang ~= "rust" then
              return
            end
            local problem_dir = vim.fn.stdpath("data") .. "/leetcode/Cargo.toml"
            local content = [[
              [package]
              name = "leetcode"
              edition = "2021"
                                                                                                     
              [lib]
              name = "%s"
              path = "%s"
                                                                                                     
              [dependencies]
              rand = "0.8"
              regex = "1"
              itertools = "0.14.0"
            ]]
            local file = io.open(problem_dir, "w")
            if file then
              local formatted = (content:gsub(" +", "")):format(question.q.frontend_id, question:path())
              file:write(formatted)
              file:close()
            else
              print("Failed to open file: " .. problem_dir)
            end
          end,
        },
      },
    },
  },
}
