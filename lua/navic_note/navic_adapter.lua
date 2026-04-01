local config = require("navic_note.config")
local note_parser = require("navic_note.note_parser")
local path = require("navic_note.path")

local M = {}

local function display_note_mark()
  local mark = config.values.note_mark or ""
  if mark == "" then
    return ""
  end
  return " " .. mark
end

local function get_navic()
  local ok, navic = pcall(require, "nvim-navic")
  if ok then
    return navic
  end
  return nil
end

function M.navic_available(bufnr)
  local navic = get_navic()
  return navic ~= nil and navic.is_available(bufnr)
end

function M.get_data(bufnr)
  if not M.navic_available(bufnr) then
    return nil
  end
  return get_navic().get_data(bufnr)
end

function M.build_symbol_paths(data)
  if not data or vim.tbl_isempty(data) then
    return {}, nil
  end

  local parts = {}
  local paths = {}
  for _, item in ipairs(data) do
    parts[#parts + 1] = item.name
    paths[#paths + 1] = table.concat(parts, config.values.path_separator)
  end
  return paths, paths[#paths]
end

function M.get_current_symbol_path(bufnr)
  local data = M.get_data(bufnr)
  local _, symbol_path = M.build_symbol_paths(data)
  return symbol_path
end

function M.get_current_symbol_ancestors(bufnr)
  local data = M.get_data(bufnr)
  local paths = M.build_symbol_paths(data)
  return paths
end

function M.render_navic_with_note_marks(bufnr, opts)
  local navic = get_navic()
  if not navic or not navic.is_available(bufnr) then
    return ""
  end

  local source_path = vim.api.nvim_buf_get_name(bufnr)
  local note_path = path.source_to_note_path(source_path)
  local parsed = note_path and note_parser.parse_note_headings(note_path) or { headings = {} }
  local data = vim.deepcopy(navic.get_data(bufnr) or {})
  local paths = M.build_symbol_paths(data)

  for idx, item in ipairs(data) do
    if parsed.headings[paths[idx]] then
      item.name = item.name .. display_note_mark()
    end
  end

  local render_opts = vim.tbl_deep_extend("force", {}, config.values.navic or {}, opts or {})
  return navic.format_data(data, render_opts)
end

return M
