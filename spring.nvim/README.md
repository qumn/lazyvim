# spring.nvim

Telescope picker for Spring MVC endpoints (Java controllers), powered by `ripgrep`.

## Features

- Scans `**/src/main/java/**` `*Controller.java` for `@RequestMapping`/`@*Mapping`.
- Shows HTTP method, full path (class-level + method-level), controller file.
- Jump to definition or copy `METHOD /path` with `<C-y>`.
- Configurable HTTP highlight groups via `hl_http`.

## Requirements

- Neovim 0.11+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Project root detection via `require("lazyvim.util").root()`
- `rg` (ripgrep) in `$PATH`

## Installation (lazy.nvim)

```lua
{
  "qumn/spring.nvim",
  dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
  config = function()
    require("spring").setup({
      -- optional overrides
      hl_http = {
        GET = "DiagnosticOk",      -- green
        POST = "DiagnosticWarn",   -- orange
        PUT = "DiagnosticHint",    -- blue
        DELETE = "DiagnosticError",-- red
      },
    })
  end,
}
```

## Usage

- `:SpringEndpoints` — open picker.
- Lua: `require("spring").endpoints()`
- Picker mappings: `<CR>` to jump, `<C-y>` to copy `METHOD /path`.

## Options

- `hl_http` (table): map HTTP method -> highlight group. Defaults above; `ANY` used as fallback.
