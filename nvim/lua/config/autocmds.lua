vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'markdown',
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.showbreak = '↪ '
    vim.opt_local.spell = true
    vim.opt_local.spelllang = 'en_us'

    vim.keymap.set('n', '<leader>jh', function()
      local location = vim.fn.input 'Location: '
      local timestamp = os.date '## %Y-%m-%d %H:%M:%S %A'
      local full_stamp = string.format('%s - %s', timestamp, location)
      vim.api.nvim_put({ full_stamp }, 'c', true, true)
    end, { desc = 'Insert [j]ournal [h]eader', buffer = true })
  end,
})
