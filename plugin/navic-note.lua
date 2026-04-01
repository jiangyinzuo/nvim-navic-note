if vim.g.loaded_navic_note == 1 then
  return
end
vim.g.loaded_navic_note = 1

require("navic_note").setup()

vim.api.nvim_create_user_command("NavicNoteToggle", function()
  require("navic_note").toggle()
end, { desc = "Toggle between code and note" })

vim.api.nvim_create_user_command("NavicNoteFiles", function(args)
  require("navic_note").search_files(args.bang)
end, {
  bang = true,
  desc = "Search note files for current repo with fzf.vim",
})

vim.api.nvim_create_user_command("NavicNoteRg", function(args)
  require("navic_note").search_rg(args.args, args.bang)
end, {
  bang = true,
  nargs = "*",
  desc = "Ripgrep note files for current repo with fzf.vim",
})
