local M = {}

local defaults = {
  notes_root = vim.fs.normalize(vim.fn.expand("~/.notes")),
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
}

M.values = vim.deepcopy(defaults)

function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M.values.notes_root = vim.fs.normalize(vim.fn.expand(M.values.notes_root))
  return M.values
end

return M
