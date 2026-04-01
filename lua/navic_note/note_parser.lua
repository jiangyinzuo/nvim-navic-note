local M = {}

local cache = {}

local function file_key(path)
  return vim.fs.normalize(path)
end

local function stat_signature(path)
  local stat = vim.uv.fs_stat(path)
  if not stat then
    return "missing"
  end
  local mtime = stat.mtime or {}
  return table.concat({
    stat.size or 0,
    mtime.sec or 0,
    mtime.nsec or 0,
  }, ":")
end

local function parse_lines(lines)
  local headings = {}
  local ordered = {}

  for idx, line in ipairs(lines) do
    local heading = line:match("^##%s+(.+)%s*$")
    if heading and heading ~= "" then
      headings[heading] = idx
      ordered[#ordered + 1] = {
        heading = heading,
        line = idx,
      }
    end
  end

  return {
    headings = headings,
    ordered = ordered,
  }
end

function M.invalidate(path)
  cache[file_key(path)] = nil
end

function M.parse_note_headings(note_path)
  local normalized = file_key(note_path)
  local signature = stat_signature(normalized)
  local cached = cache[normalized]
  if cached and cached.signature == signature then
    return cached.data
  end

  local lines = vim.fn.filereadable(normalized) == 1 and vim.fn.readfile(normalized) or {}
  local data = parse_lines(lines)
  cache[normalized] = {
    signature = signature,
    data = data,
  }
  return data
end

function M.find_heading(note_path, symbol_path)
  local parsed = M.parse_note_headings(note_path)
  return parsed.headings[symbol_path]
end

function M.find_nearest_ancestor_heading(note_path, symbol_paths)
  for i = #symbol_paths, 1, -1 do
    local line = M.find_heading(note_path, symbol_paths[i])
    if line then
      return line, symbol_paths[i]
    end
  end
  return nil, nil
end

function M.current_heading_under_cursor(bufnr)
  bufnr = bufnr or 0
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  for line = cursor, 1, -1 do
    local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
    local heading = text and text:match("^##%s+(.+)%s*$")
    if heading then
      return heading, line
    end
  end
  return nil, nil
end

local function append_heading_to_loaded_buffer(bufnr, note_path, heading)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 1 and lines[1] == "" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "## " .. heading,
      "",
    })
    M.invalidate(note_path)
    return 1
  end
  if #lines > 0 and lines[#lines] ~= "" then
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
    lines[#lines + 1] = ""
  end
  local heading_line = #lines + 1
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {
    "## " .. heading,
    "",
  })
  M.invalidate(note_path)
  return heading_line
end

function M.append_heading(note_path, heading, bufnr)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    return append_heading_to_loaded_buffer(bufnr, note_path, heading)
  end

  local loaded = vim.fn.bufnr(note_path)
  if loaded ~= -1 and vim.api.nvim_buf_is_loaded(loaded) then
    return append_heading_to_loaded_buffer(loaded, note_path, heading)
  end

  local lines = vim.fn.filereadable(note_path) == 1 and vim.fn.readfile(note_path) or {}
  if #lines > 0 and lines[#lines] ~= "" then
    lines[#lines + 1] = ""
  end
  local heading_line = #lines + 1
  lines[#lines + 1] = "## " .. heading
  lines[#lines + 1] = ""
  vim.fn.writefile(lines, note_path)
  M.invalidate(note_path)
  return heading_line
end

return M
