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

T["parse_note_headings() indexes only level-2 headings"] = function()
  local tmp = helpers.make_temp_dir()
  local note_path = vim.fs.joinpath(tmp, "a.md")
  helpers.write_file(note_path, {
    "# title",
    "## alpha",
    "text",
    "### ignored",
    "## beta",
  })

  helpers.setup_plugin()
  local parser = require("navic_note.note_parser")
  local parsed = parser.parse_note_headings(note_path)

  eq(parsed.headings.alpha, 2)
  eq(parsed.headings.beta, 5)
  eq(parsed.headings.ignored, nil)
end

T["current_heading_under_cursor() finds nearest previous level-2 heading"] = function()
  local tmp = helpers.make_temp_dir()
  local note_path = vim.fs.joinpath(tmp, "b.md")
  helpers.write_file(note_path, {
    "## alpha",
    "body",
    "### sub",
    "body2",
    "## beta",
    "body3",
  })

  helpers.setup_plugin()
  vim.cmd("edit " .. vim.fn.fnameescape(note_path))
  vim.api.nvim_win_set_cursor(0, { 4, 0 })

  local parser = require("navic_note.note_parser")
  local heading, line = parser.current_heading_under_cursor(0)
  eq(heading, "alpha")
  eq(line, 1)
end

T["append_heading() inserts into a fresh loaded buffer"] = function()
  local tmp = helpers.make_temp_dir()
  local note_path = vim.fs.joinpath(tmp, "fresh.md")

  helpers.setup_plugin()
  vim.cmd("edit " .. vim.fn.fnameescape(note_path))
  local bufnr = vim.api.nvim_get_current_buf()

  local parser = require("navic_note.note_parser")
  local line = parser.append_heading(note_path, "mod::fun", bufnr)
  eq(line, 1)
  eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "## mod::fun", "" })
end

T["append_heading() appends after content with a blank separator"] = function()
  local tmp = helpers.make_temp_dir()
  local note_path = vim.fs.joinpath(tmp, "append.md")
  helpers.write_file(note_path, { "## alpha", "body" })

  helpers.setup_plugin()
  vim.cmd("edit " .. vim.fn.fnameescape(note_path))
  local bufnr = vim.api.nvim_get_current_buf()

  local parser = require("navic_note.note_parser")
  local line = parser.append_heading(note_path, "beta", bufnr)
  eq(line, 4)
  eq(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), {
    "## alpha",
    "body",
    "",
    "## beta",
    "",
  })
end

return T
