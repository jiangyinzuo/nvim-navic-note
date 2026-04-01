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

T["source_to_note_path() maps source into notes root"] = function()
  local tmp = helpers.make_temp_dir()
  local repo = vim.fs.joinpath(tmp, "repo")
  local source = vim.fs.joinpath(repo, "src", "mod.c")
  local notes_root = vim.fs.joinpath(tmp, "notes")

  vim.fn.mkdir(vim.fs.dirname(source), "p")
  helpers.write_file(source, { "int main(void) { return 0; }" })
  helpers.git_init(repo)

  helpers.setup_plugin({ notes_root = notes_root })
  local path = require("navic_note.path")
  local note_path, err, meta = path.source_to_note_path(source)

  eq(err, nil)
  eq(note_path, vim.fs.joinpath(notes_root, "repo", "src", "mod.c.md"))
  eq(meta.repo_name, "repo")
  eq(meta.relative_path, "src/mod.c")
end

T["note_to_source_path() uses configured repo_roots"] = function()
  local tmp = helpers.make_temp_dir()
  local repo = vim.fs.joinpath(tmp, "demo")
  local source = vim.fs.joinpath(repo, "lua", "x.lua")
  local notes_root = vim.fs.joinpath(tmp, "notes")
  local note_path = vim.fs.joinpath(notes_root, "demo", "lua", "x.lua.md")

  vim.fn.mkdir(vim.fs.dirname(source), "p")
  helpers.write_file(source, { "return {}" })
  helpers.write_file(note_path, { "## mod::x", "" })
  helpers.git_init(repo)

  helpers.setup_plugin({
    notes_root = notes_root,
    repo_roots = {
      demo = repo,
    },
  })

  local path = require("navic_note.path")
  local resolved, err = path.note_to_source_path(note_path)
  eq(err, nil)
  eq(resolved, source)
end

T["is_note_path() rejects sibling prefixes"] = function()
  local tmp = helpers.make_temp_dir()
  local notes_root = vim.fs.joinpath(tmp, "notes")

  helpers.setup_plugin({ notes_root = notes_root })
  local path = require("navic_note.path")

  eq(path.is_note_path(vim.fs.joinpath(notes_root, "repo", "a.md")), true)
  eq(path.is_note_path(notes_root .. "-other/repo/a.md"), false)
end

T["current_note_repo_dir() resolves from code and note buffers"] = function()
  local tmp = helpers.make_temp_dir()
  local repo = vim.fs.joinpath(tmp, "repo")
  local source = vim.fs.joinpath(repo, "src", "mod.c")
  local notes_root = vim.fs.joinpath(tmp, "notes")
  local note_path = vim.fs.joinpath(notes_root, "repo", "src", "mod.c.md")

  vim.fn.mkdir(vim.fs.dirname(source), "p")
  helpers.write_file(source, { "int x;" })
  helpers.write_file(note_path, { "## mod", "" })
  helpers.git_init(repo)

  helpers.setup_plugin({ notes_root = notes_root })
  local path = require("navic_note.path")

  vim.cmd("edit " .. vim.fn.fnameescape(source))
  local from_code = path.current_note_repo_dir(0)
  eq(from_code, vim.fs.joinpath(notes_root, "repo"))

  vim.cmd("edit " .. vim.fn.fnameescape(note_path))
  local from_note = path.current_note_repo_dir(0)
  eq(from_note, vim.fs.joinpath(notes_root, "repo"))
end

return T
