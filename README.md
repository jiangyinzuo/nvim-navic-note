# nvim-navic-note

A Neovim plugin that links source code symbols and Markdown notes through `nvim-navic` and LSP.

It provides:

- code -> note jump with `<leader>nv`
- note -> code jump with the same key
- per-segment note marks in navic breadcrumbs
- one Markdown note file per source file

## Requirements

- Neovim
- `SmiteshP/nvim-navic`
- an attached LSP client with `documentSymbolProvider`
- `git`

## Note Layout

Source file:

```text
/path/to/repo/src/foo/bar.lua
```

Default note file:

```text
~/.notes/repo/src/foo/bar.lua.md
```

Symbol notes are stored as Markdown `##` headings:

```md
## module::Class::method

Notes for this symbol.
```

## Behavior

- In a code buffer, `<leader>nv` opens or reuses the note window and jumps to the current symbol note.
- If no matching ancestor heading exists, the plugin appends an empty `## <symbol_path>` heading.
- In a note buffer, `<leader>nv` opens or reuses the source window and jumps back to the symbol.
- `require("navic_note").get_location()` returns navic breadcrumb text with note marks appended to segments that already have notes.

## lazy.nvim

```lua
{
  "jiangyinzuo/nvim-navic-note",
  dependencies = {
    "neovim/nvim-lspconfig",
    "SmiteshP/nvim-navic",
  },
  config = function()
    require("navic_note").setup({
      notes_root = vim.fn.expand("~/.notes"),
      keymap = "<leader>nv",
      create_default_keymap = true,
      auto_set_winbar = false,
    })
  end,
}
```

## lualine

`nvim-navic-note` provides a lualine component named `"navic_note"`.

```lua
require("lualine").setup({
  winbar = {
    lualine_c = {
      "navic_note",
    },
  },
})
```

With options:

```lua
require("lualine").setup({
  winbar = {
    lualine_c = {
      {
        "navic_note",
        color_correction = "static",
        navic_opts = {
          separator = " > ",
        },
      },
    },
  },
})
```

If `lualine` is already managing your `winbar`, keep `auto_set_winbar = false` in `navic_note.setup()`.

If you want to use the marked breadcrumb in your own winbar:

```lua
vim.o.winbar = "%{%v:lua.NavicNoteGetLocation()%}"
```

If you prefer the plugin to set it automatically for normal code buffers:

```lua
require("navic_note").setup({
  auto_set_winbar = true,
})
```

## LSP Setup Example

`nvim-navic` must be attached to the LSP client:

```lua
local navic = require("nvim-navic")

require("lspconfig").clangd.setup({
  on_attach = function(client, bufnr)
    if client.server_capabilities.documentSymbolProvider then
      navic.attach(client, bufnr)
    end
  end,
})
```

## Options

Default config:

```lua
require("navic_note").setup({
  notes_root = vim.fn.expand("~/.notes"),
  note_mark = "󱞁",
  path_separator = "::",
  keymap = "<leader>nv",
  create_default_keymap = true,
  auto_set_winbar = false,
  repo_roots = {},
  navic = {
    separator = " > ",
  },
  lsp_timeout_ms = 800,
})
```

`repo_roots` can be used when opening a note before the repo has been discovered from current buffers or recent files:

```lua
require("navic_note").setup({
  repo_roots = {
    myrepo = "/path/to/myrepo",
  },
})
```

## Commands

- `:NavicNoteToggle`

## Testing

Run tests with:

```bash
./scripts/test
```

The test runner uses `mini.test`. If `mini.nvim` is not already available in a common local plugin path, it will be cloned automatically into `.tests/deps/mini.nvim`.
