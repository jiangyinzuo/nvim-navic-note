local path = require("navic_note.path")

local M = {}
local augroup = vim.api.nvim_create_augroup("NavicNoteFzf", { clear = true })

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-navic-note" })
end

local function note_repo_dir()
  local dir, err = path.current_note_repo_dir(0)
  if not dir then
    notify(err, vim.log.levels.ERROR)
    return nil
  end
  vim.fn.mkdir(dir, "p")
  return dir
end

local function popup_window()
  return {
    width = 0.9,
    height = 0.85,
  }
end

local function with_preview(spec)
  return vim.fn["fzf#vim#with_preview"](spec, "right,50%", "ctrl-/")
end

local function fzf_spec(prompt, dir)
  return with_preview({
    dir = dir,
    window = popup_window(),
    options = {
      "--prompt",
      prompt,
    },
  })
end

local function prepare_fzf_window()
  local origin_buf = vim.api.nvim_get_current_buf()
  local can_toggle_codelens = vim.lsp
    and vim.lsp.codelens
    and type(vim.lsp.codelens.enable) == "function"

  if can_toggle_codelens then
    pcall(vim.lsp.codelens.enable, false, { bufnr = origin_buf })
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "fzf",
    once = true,
    callback = function(args)
      vim.bo[args.buf].buflisted = false
      if can_toggle_codelens then
        vim.api.nvim_create_autocmd("TermClose", {
          group = augroup,
          buffer = args.buf,
          once = true,
          callback = function()
            vim.schedule(function()
              pcall(vim.lsp.codelens.enable, true, { bufnr = origin_buf })
            end)
          end,
        })
      end
    end,
  })
end

local function shellescape(text)
  return vim.fn["fzf#shellescape"](text)
end

local function set_window_width_ratio(win, ratio)
  local width = math.max(20, math.floor(vim.o.columns * ratio))
  pcall(vim.api.nvim_win_set_width, win, width)
end

local function open_in_right_split(file_path, line, col)
  vim.schedule(function()
    vim.cmd("rightbelow vsplit")
    local win = vim.api.nvim_get_current_win()
    set_window_width_ratio(win, 1 / 3)
    vim.cmd("edit " .. vim.fn.fnameescape(file_path))
    if line then
      vim.api.nvim_win_set_cursor(win, { line, math.max((col or 1) - 1, 0) })
      vim.cmd("normal! zz")
    end
  end)
end

local function normalize_selected_path(dir, selected)
  if vim.startswith(selected, "/") then
    return selected
  end
  return vim.fs.joinpath(dir, selected)
end

local function file_sink(dir, lines)
  local selected = lines[#lines]
  if not selected or selected == "" then
    return
  end
  open_in_right_split(normalize_selected_path(dir, selected))
end

local function grep_sink(dir, lines)
  local selected = lines[#lines]
  if not selected or selected == "" then
    return
  end

  local file, lnum, col = selected:match("^([^:]+):(%d+):(%d+):")
  if not file then
    file = selected:match("^([^:]+):")
  end
  if not file then
    return
  end

  open_in_right_split(normalize_selected_path(dir, file), tonumber(lnum or "1"), tonumber(col or "1"))
end

function M.files(bang)
  local dir = note_repo_dir()
  if not dir then
    return
  end

  prepare_fzf_window()
  local spec = fzf_spec("NoteFiles> ", dir)
  spec["sink*"] = function(lines)
    file_sink(dir, lines)
  end
  vim.fn["fzf#vim#files"](dir, spec, bang and 1 or 0)
end

function M.rg(query, bang)
  local dir = note_repo_dir()
  if not dir then
    return
  end

  prepare_fzf_window()
  local command = "rg --column --line-number --no-heading --color=always --smart-case -- " .. shellescape(query or "")
  local spec = fzf_spec("NoteRg> ", dir)
  spec["sink*"] = function(lines)
    grep_sink(dir, lines)
  end
  vim.fn["fzf#vim#grep"](command, spec, bang and 1 or 0)
end

return M
