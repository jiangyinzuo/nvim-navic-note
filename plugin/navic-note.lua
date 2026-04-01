if vim.g.loaded_navic_note == 1 then
  return
end
vim.g.loaded_navic_note = 1

require("navic_note").setup()

vim.api.nvim_create_user_command("NavicNoteToggle", function()
  require("navic_note").toggle()
end, { desc = "Toggle between code and note" })
