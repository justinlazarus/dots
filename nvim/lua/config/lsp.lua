-- Suppress deprecation warnings from Neovim dev builds
vim.deprecate = function() end

-- Enable LSP servers (roslyn is handled separately in plugin.lua)
vim.lsp.enable {
  'lua_ls',
  'ts_ls',
}

-- When an LSP attaches, set buffer-local keymaps for code actions
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
    vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
  end,
})

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
