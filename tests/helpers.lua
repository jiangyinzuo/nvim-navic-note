local M = {}

function M.expect_eq(left, right)
  MiniTest.expect.equality(left, right)
end

function M.make_temp_dir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  return vim.fs.normalize(path)
end

function M.write_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

function M.git_init(path)
  vim.fn.system({ "git", "-C", path, "init", "-q" })
  if vim.v.shell_error ~= 0 then
    error("failed to init git repo at " .. path)
  end
end

function M.reset_editor()
  vim.cmd("silent! %bwipeout!")
  vim.cmd("silent! only")
end

function M.setup_plugin(opts)
  package.loaded["navic_note"] = nil
  package.loaded["navic_note.config"] = nil
  package.loaded["navic_note.jump"] = nil
  package.loaded["navic_note.navic_adapter"] = nil
  package.loaded["navic_note.note_parser"] = nil
  package.loaded["navic_note.path"] = nil

  local note = require("navic_note")
  note.setup(vim.tbl_deep_extend("force", {
    create_default_keymap = false,
    auto_set_winbar = false,
  }, opts or {}))
  return note
end

return M
