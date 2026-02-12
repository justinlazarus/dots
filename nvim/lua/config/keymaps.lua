vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('n', '<leader>fe', '<cmd>Oil<CR>', { desc = '[F]ilesystem [E]xplore' })

---------------------------------------------------------------------------------------------------- vim.pack
vim.api.nvim_create_user_command('UpdateAll', function()
  print 'Updating plugins...'
  vim.pack.update()

  local ok, ts_install = pcall(require, 'nvim-treesitter.install')
  if ok then
    print 'Updating Treesitter parsers...'
    ts_install.update { with_sync = true }
  end

  print 'Update complete!'
end, { desc = 'Update plugins and Treesitter parsers' })

vim.keymap.set('n', '<leader>op', function()
  Snacks.picker.files { cmd = 'dotnet', args = { 'list', 'project' } }
end, { desc = 'Dotnet: List Projects' })
