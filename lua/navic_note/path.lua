local config = require("navic_note.config")

local M = {}

local function systemlist(cmd)
  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  if output[1] == nil or output[1] == "" then
    return nil
  end
  return output[1]
end

local function dirname(path)
  return vim.fs.dirname(vim.fs.normalize(path))
end

local function git_target(filepath)
  filepath = vim.fs.normalize(filepath)
  local stat = vim.uv.fs_stat(filepath)
  if stat and stat.type == "directory" then
    return filepath
  end
  return dirname(filepath)
end

local function has_path_prefix(path, prefix)
  path = vim.fs.normalize(path)
  prefix = vim.fs.normalize(prefix)
  return path == prefix or vim.startswith(path, prefix .. "/")
end

function M.get_git_root(filepath)
  local dir = git_target(filepath)
  local escaped = vim.fn.fnameescape(dir)
  local root = systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if root then
    return vim.fs.normalize(root)
  end

  local alt = systemlist("git -C " .. escaped .. " rev-parse --show-toplevel 2>/dev/null")
  return alt and vim.fs.normalize(alt) or nil
end

function M.get_relative_source_path(source_path, root)
  source_path = vim.fs.normalize(source_path)
  root = vim.fs.normalize(root)
  if not has_path_prefix(source_path, root) then
    return nil
  end
  return source_path:sub(#root + 2)
end

function M.source_to_note_path(source_path)
  local root = M.get_git_root(source_path)
  if not root then
    return nil, "git root not found"
  end

  local rel = M.get_relative_source_path(source_path, root)
  if not rel then
    return nil, "failed to resolve relative source path"
  end

  local repo_name = vim.fs.basename(root)
  local note_path = vim.fs.joinpath(config.values.notes_root, repo_name, rel .. ".md")
  return vim.fs.normalize(note_path), nil, {
    git_root = root,
    repo_name = repo_name,
    relative_path = rel,
  }
end

local function find_repo_root_by_name(repo_name)
  local configured = config.values.repo_roots[repo_name]
  if configured and configured ~= "" then
    return vim.fs.normalize(vim.fn.expand(configured))
  end

  local cwd_root = M.get_git_root(vim.fn.getcwd())
  if cwd_root and vim.fs.basename(cwd_root) == repo_name then
    return cwd_root
  end

  local seen = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and not seen[name] then
      seen[name] = true
      local root = M.get_git_root(name)
      if root and vim.fs.basename(root) == repo_name then
        return root
      end
    end
  end

  for _, oldfile in ipairs(vim.v.oldfiles or {}) do
    local root = M.get_git_root(oldfile)
    if root and vim.fs.basename(root) == repo_name then
      return root
    end
  end

  return nil
end

function M.note_to_source_path(note_path)
  note_path = vim.fs.normalize(note_path)
  local note_root = config.values.notes_root
  if not has_path_prefix(note_path, note_root) then
    return nil, "note is outside notes_root"
  end

  local rel = note_path:sub(#note_root + 2)
  local parts = vim.split(rel, "/", { plain = true, trimempty = true })
  if #parts < 2 then
    return nil, "invalid note path"
  end

  local repo_name = table.remove(parts, 1)
  local joined = table.concat(parts, "/")
  if not vim.endswith(joined, ".md") then
    return nil, "note must end with .md"
  end

  local rel_source = joined:sub(1, -4)
  local repo_root = find_repo_root_by_name(repo_name)
  if not repo_root then
    return nil, ("repo root not found for %s"):format(repo_name)
  end

  return vim.fs.normalize(vim.fs.joinpath(repo_root, rel_source)), nil, {
    repo_name = repo_name,
    git_root = repo_root,
    relative_path = rel_source,
  }
end

function M.is_note_path(path)
  if path == nil or path == "" then
    return false
  end
  path = vim.fs.normalize(path)
  return has_path_prefix(path, config.values.notes_root) and vim.endswith(path, ".md")
end

function M.ensure_note_file(note_path)
  local dir = vim.fs.dirname(note_path)
  vim.fn.mkdir(dir, "p")
  local fd = vim.uv.fs_open(note_path, "a", 420)
  if fd then
    vim.uv.fs_close(fd)
  end
end

function M.note_repo_dir_from_path(pathname)
  pathname = vim.fs.normalize(pathname)
  local note_root = vim.fs.normalize(config.values.notes_root)
  if not has_path_prefix(pathname, note_root) then
    return nil, "path is outside notes_root"
  end

  local rel = pathname:sub(#note_root + 2)
  local repo_name = vim.split(rel, "/", { plain = true, trimempty = true })[1]
  if not repo_name or repo_name == "" then
    return nil, "repo name not found from note path"
  end

  return vim.fs.joinpath(note_root, repo_name), nil, repo_name
end

function M.current_note_repo_dir(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if M.is_note_path(name) then
    return M.note_repo_dir_from_path(name)
  end

  local root = nil
  if name ~= "" then
    root = M.get_git_root(name)
  end
  if not root then
    root = M.get_git_root(vim.fn.getcwd())
  end
  if not root then
    return nil, "git root not found for current buffer"
  end

  local repo_name = vim.fs.basename(root)
  return vim.fs.joinpath(config.values.notes_root, repo_name), nil, repo_name
end

return M
