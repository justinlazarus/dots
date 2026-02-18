vim.lsp.enable { 'lua_ls', 'ts_ls', 'jsonls', 'yamlls', 'angularls', 'rust_analyzer', 'terraform_ls', 'gopls' }

vim.api.nvim_create_user_command('LspLog', function()
  vim.cmd.edit(vim.lsp.log.get_filename())
end, { desc = 'Open LSP log file' })

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}

-- Rounded borders on hover and signature help
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local buf = args.buf
    vim.keymap.set('n', 'K', function()
      vim.lsp.buf.hover { border = 'rounded' }
    end, { buffer = buf })
    vim.keymap.set({ 'n', 'i' }, '<C-s>', function()
      vim.lsp.buf.signature_help { border = 'rounded' }
    end, { buffer = buf })
  end,
})
