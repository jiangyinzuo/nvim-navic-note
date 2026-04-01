local repo_root = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h"))

local function ensure_mini()
  local vendored = vim.fs.joinpath(repo_root, ".tests", "deps", "mini.nvim")
  local candidates = {
    vim.env.MINI_NVIM_PATH,
    vendored,
    "/root/.local/share/nvim/lazy/mini.nvim",
    "/root/plugged/mini.nvim",
  }

  for _, path in ipairs(candidates) do
    if path and path ~= "" and vim.fn.filereadable(vim.fs.joinpath(path, "lua", "mini", "test.lua")) == 1 then
      return vim.fs.normalize(path)
    end
  end

  if vim.fn.isdirectory(vendored) == 1 then
    vim.fn.delete(vendored, "rf")
  end

  vim.fn.mkdir(vim.fs.dirname(vendored), "p")
  local out = vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "https://github.com/echasnovski/mini.nvim",
    vendored,
  })
  if vim.v.shell_error ~= 0 then
    error("failed to clone mini.nvim for tests:\n" .. out)
  end
  return vendored
end

vim.opt.runtimepath:prepend(ensure_mini())
vim.opt.runtimepath:prepend(repo_root)

require("mini.test").setup({
  collect = {
    find_files = function()
      return vim.fn.globpath(vim.fs.joinpath(repo_root, "tests"), "test_*.lua", true, true)
    end,
  },
  execute = {
    reporter = require("mini.test").gen_reporter.stdout(),
  },
  script_path = "",
  silent = false,
})
