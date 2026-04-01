local config = require("navic_note.config")
local navic_adapter = require("navic_note.navic_adapter")
local note_parser = require("navic_note.note_parser")
local path = require("navic_note.path")

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-navic-note" })
end

local function get_normal_windows()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bt = vim.bo[buf].buftype
    if bt == "" then
      wins[#wins + 1] = win
    end
  end
  return wins
end

local function set_window_width_ratio(win, ratio)
  local columns = vim.o.columns
  local width = math.max(20, math.floor(columns * ratio))
  pcall(vim.api.nvim_win_set_width, win, width)
end

function M.open_or_reuse_note_window(note_path)
  local current_win = vim.api.nvim_get_current_win()
  local wins = get_normal_windows()

  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == note_path then
      return win
    end
  end

  for _, win in ipairs(wins) do
    if win ~= current_win then
      local buf = vim.api.nvim_win_get_buf(win)
      if path.is_note_path(vim.api.nvim_buf_get_name(buf)) then
        return win
      end
    end
  end

  if #wins <= 1 then
    vim.cmd("rightbelow vsplit")
    local win = vim.api.nvim_get_current_win()
    set_window_width_ratio(win, 1 / 3)
    return win
  end

  for _, win in ipairs(wins) do
    if win ~= current_win then
      return win
    end
  end

  return current_win
end

function M.open_or_reuse_code_window(source_path)
  local current_win = vim.api.nvim_get_current_win()
  local wins = get_normal_windows()

  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == source_path then
      return win
    end
  end

  for _, win in ipairs(wins) do
    if win ~= current_win then
      local buf = vim.api.nvim_win_get_buf(win)
      if not path.is_note_path(vim.api.nvim_buf_get_name(buf)) then
        return win
      end
    end
  end

  if #wins <= 1 then
    vim.cmd("leftabove vsplit")
    local win = vim.api.nvim_get_current_win()
    set_window_width_ratio(win, 2 / 3)
    return win
  end

  for _, win in ipairs(wins) do
    if win ~= current_win then
      return win
    end
  end

  return current_win
end

local function jump_to_line(win, line)
  vim.api.nvim_set_current_win(win)
  local max_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
  local target = math.min(math.max(line or 1, 1), math.max(max_line, 1))
  vim.api.nvim_win_set_cursor(win, { target, 0 })
  vim.cmd("normal! zz")
end

local function heading_candidates(bufnr)
  local ancestors = navic_adapter.get_current_symbol_ancestors(bufnr)
  if type(ancestors) ~= "table" then
    return {}
  end
  return ancestors
end

local function insert_heading_if_missing(note_path, symbol_path, bufnr)
  if not symbol_path or symbol_path == "" then
    return nil
  end
  return note_parser.append_heading(note_path, symbol_path, bufnr)
end

local function edit_in_window(win, file_path)
  vim.api.nvim_set_current_win(win)
  vim.cmd("edit " .. vim.fn.fnameescape(file_path))
end

local function note_window_cwd(note_path)
  note_path = vim.fs.normalize(note_path)
  local note_root = vim.fs.normalize(config.values.notes_root)
  local rel = note_path:sub(#note_root + 2)
  local repo_name = vim.split(rel, "/", { plain = true, trimempty = true })[1]
  if not repo_name or repo_name == "" then
    return nil
  end
  return vim.fs.joinpath(note_root, repo_name)
end

local function set_note_window_cwd(win, note_path)
  local cwd = note_window_cwd(note_path)
  if not cwd then
    return
  end
  vim.fn.mkdir(cwd, "p")
  vim.api.nvim_win_call(win, function()
    vim.cmd("lcd " .. vim.fn.fnameescape(cwd))
  end)
end

function M.jump_code_to_note()
  local bufnr = vim.api.nvim_get_current_buf()
  local source_path = vim.api.nvim_buf_get_name(bufnr)
  if source_path == "" then
    notify("current buffer has no file path", vim.log.levels.ERROR)
    return
  end

  local note_path, err = path.source_to_note_path(source_path)
  if not note_path then
    notify(err, vim.log.levels.ERROR)
    return
  end

  path.ensure_note_file(note_path)

  local win = M.open_or_reuse_note_window(note_path)
  edit_in_window(win, note_path)
  set_note_window_cwd(win, note_path)
  local note_bufnr = vim.api.nvim_win_get_buf(win)

  local current_symbol = navic_adapter.get_current_symbol_path(bufnr)
  local ancestors = heading_candidates(bufnr)
  local line = current_symbol and note_parser.find_heading(note_path, current_symbol) or nil

  if not line then
    line = select(1, note_parser.find_nearest_ancestor_heading(note_path, ancestors))
  end

  if not line and current_symbol then
    line = insert_heading_if_missing(note_path, current_symbol, note_bufnr)
  end

  if line then
    jump_to_line(win, line)
  else
    jump_to_line(win, 1)
    if not navic_adapter.navic_available(bufnr) then
      notify("navic context unavailable, opened note file only")
    else
      notify("no note heading found for current symbol or ancestors")
    end
  end
end

local function document_symbols(bufnr)
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/documentSymbol", params, config.values.lsp_timeout_ms)
  if not responses then
    return nil
  end

  for _, response in pairs(responses) do
    if response.result and not vim.tbl_isempty(response.result) then
      return response.result
    end
  end
  return nil
end

local function selection_start(symbol)
  local range = symbol.selectionRange or symbol.range
  if not range or not range.start then
    return nil
  end
  return {
    line = range.start.line + 1,
    col = range.start.character,
  }
end

local function find_symbol_chain(symbols, segments, depth)
  depth = depth or 1
  if type(symbols) ~= "table" then
    return nil
  end

  for _, symbol in ipairs(symbols) do
    if symbol.name == segments[depth] then
      if depth == #segments then
        return symbol
      end
      local child = find_symbol_chain(symbol.children, segments, depth + 1)
      if child then
        return child
      end
    end
  end
  return nil
end

local function find_symbol_by_name(symbols, name)
  if type(symbols) ~= "table" then
    return nil
  end
  for _, symbol in ipairs(symbols) do
    if symbol.name == name then
      return symbol
    end
    local child = find_symbol_by_name(symbol.children, name)
    if child then
      return child
    end
  end
  return nil
end

local function locate_symbol_in_buffer(bufnr, symbol_path)
  local symbols = document_symbols(bufnr)
  local segments = vim.split(symbol_path, config.values.path_separator, { plain = true, trimempty = true })
  local symbol = find_symbol_chain(symbols, segments)
  if not symbol then
    symbol = find_symbol_by_name(symbols, segments[#segments])
  end

  local pos = symbol and selection_start(symbol)
  if pos then
    return pos
  end

  local pattern = "\\V" .. vim.fn.escape(segments[#segments], "\\")
  local line = vim.api.nvim_buf_call(bufnr, function()
    return vim.fn.search(pattern, "nw")
  end)
  if line > 0 then
    return { line = line, col = 0 }
  end
  return nil
end

function M.jump_note_to_code()
  local bufnr = vim.api.nvim_get_current_buf()
  local note_path = vim.api.nvim_buf_get_name(bufnr)
  local source_path, err = path.note_to_source_path(note_path)
  if not source_path then
    notify(err, vim.log.levels.ERROR)
    return
  end

  if vim.fn.filereadable(source_path) ~= 1 then
    notify(("source file not found: %s"):format(source_path), vim.log.levels.ERROR)
    return
  end

  local symbol_path = note_parser.current_heading_under_cursor(bufnr)
  local win = M.open_or_reuse_code_window(source_path)
  edit_in_window(win, source_path)

  if not symbol_path then
    jump_to_line(win, 1)
    notify("no `##` heading found above cursor, opened source file only")
    return
  end

  local target_buf = vim.api.nvim_win_get_buf(win)
  local pos = locate_symbol_in_buffer(target_buf, symbol_path)
  if pos then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { pos.line, pos.col })
    vim.cmd("normal! zz")
  else
    notify(("symbol not located precisely, opened source: %s"):format(symbol_path))
  end
end

function M.toggle_note_or_code()
  local name = vim.api.nvim_buf_get_name(0)
  if path.is_note_path(name) then
    M.jump_note_to_code()
  else
    M.jump_code_to_note()
  end
end

return M
