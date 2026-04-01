local helpers = dofile("tests/helpers.lua")

local eq = helpers.expect_eq
local new_set = MiniTest.new_set

local T = new_set({
  hooks = {
    pre_case = function()
      helpers.reset_editor()
    end,
  },
})

T["jump_code_to_note() appends heading when note is first opened"] = function()
  local tmp = helpers.make_temp_dir()
  local repo = vim.fs.joinpath(tmp, "repo")
  local notes_root = vim.fs.joinpath(tmp, "notes")
  local source = vim.fs.joinpath(repo, "src", "main.c")

  vim.fn.mkdir(vim.fs.dirname(source), "p")
  helpers.write_file(source, { "int main(void) { return 0; }" })
  helpers.git_init(repo)

  helpers.setup_plugin({ notes_root = notes_root })
  vim.cmd("edit " .. vim.fn.fnameescape(source))

  local navic_adapter = require("navic_note.navic_adapter")
  local original = {
    get_current_symbol_path = navic_adapter.get_current_symbol_path,
    get_current_symbol_ancestors = navic_adapter.get_current_symbol_ancestors,
    navic_available = navic_adapter.navic_available,
  }

  navic_adapter.get_current_symbol_path = function()
    return "main"
  end
  navic_adapter.get_current_symbol_ancestors = function()
    return { "main" }
  end
  navic_adapter.navic_available = function()
    return true
  end

  local restore = function()
    navic_adapter.get_current_symbol_path = original.get_current_symbol_path
    navic_adapter.get_current_symbol_ancestors = original.get_current_symbol_ancestors
    navic_adapter.navic_available = original.navic_available
  end

  local ok, err = pcall(require("navic_note.jump").jump_code_to_note)
  restore()
  if not ok then
    error(err)
  end

  local note_path = vim.fs.joinpath(notes_root, "repo", "src", "main.c.md")
  eq(vim.api.nvim_buf_get_name(0), note_path)
  eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "## main", "" })
  eq(vim.fn.getcwd(0), vim.fs.joinpath(notes_root, "repo"))
end

return T
