local config = require("navic_note.config")
local jump = require("navic_note.jump")
local navic_adapter = require("navic_note.navic_adapter")
local note_parser = require("navic_note.note_parser")
local path = require("navic_note.path")

local M = {}

local augroup = vim.api.nvim_create_augroup("NavicNote", { clear = true })
local keymap_applied = false

function _G.NavicNoteGetLocation()
  return require("navic_note").get_location()
end

local function should_manage_winbar(bufnr)
  if not config.values.auto_set_winbar then
    return false
  end
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and not path.is_note_path(name) and vim.bo[bufnr].buftype == ""
end

local function set_winbar(bufnr)
  if should_manage_winbar(bufnr) then
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 then
      vim.wo[winid].winbar = "%{%v:lua.NavicNoteGetLocation()%}"
    end
  end
end

local function refresh_note_cache(args)
  local name = vim.api.nvim_buf_get_name(args.buf)
  if path.is_note_path(name) then
    note_parser.invalidate(name)
  end
end

local function apply_keymap()
  if keymap_applied or not config.values.create_default_keymap or not config.values.keymap then
    return
  end

  vim.keymap.set("n", config.values.keymap, function()
    require("navic_note").toggle()
  end, { desc = "Toggle between code and note" })
  keymap_applied = true
end

function M.setup(opts)
  config.setup(opts)
  vim.api.nvim_clear_autocmds({ group = augroup })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = refresh_note_cache,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = augroup,
    callback = function(args)
      set_winbar(args.buf)
    end,
  })

  apply_keymap()
end

function M.toggle()
  jump.toggle_note_or_code()
end

function M.get_location(opts, bufnr)
  return navic_adapter.render_navic_with_note_marks(bufnr or vim.api.nvim_get_current_buf(), opts)
end

function M.winbar()
  return M.get_location()
end

function M.refresh(pathname)
  note_parser.invalidate(pathname)
end

function M.is_note_buffer(bufnr)
  bufnr = bufnr or 0
  return path.is_note_path(vim.api.nvim_buf_get_name(bufnr))
end

return M
