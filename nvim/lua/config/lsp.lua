-- When an LSP attaches, set buffer-local keymaps for code actions
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
    vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
  end,
})

-- Enable LSP servers (auto-discovered from lsp/*.lua files)
vim.lsp.enable 'lua_ls'
vim.lsp.enable 'ts_ls'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'angularls'

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
