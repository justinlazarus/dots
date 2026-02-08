-- When an LSP attaches, set buffer-local keymaps
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local buf = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end

    map('n', 'K', function()
      vim.lsp.buf.hover { border = 'rounded' }
    end, 'Hover')
    map('n', '<C-s>', function()
      vim.lsp.buf.signature_help { border = 'rounded' }
    end, 'Signature Help')
    map('i', '<C-s>', function()
      vim.lsp.buf.signature_help { border = 'rounded' }
    end, 'Signature Help')
    map('n', '<leader>ca', vim.lsp.buf.code_action, 'Code Action')
    map('v', '<leader>ca', vim.lsp.buf.code_action, 'Code Action')
    map('n', '<leader>cr', vim.lsp.buf.rename, 'Rename Symbol')
    map('n', '[d', vim.diagnostic.goto_prev, 'Prev Diagnostic')
    map('n', ']d', vim.diagnostic.goto_next, 'Next Diagnostic')
  end,
})

-- Enable LSP servers (auto-discovered from lsp/*.lua files)
vim.lsp.enable 'lua_ls'
vim.lsp.enable 'ts_ls'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'yamlls'
vim.lsp.enable 'angularls'
vim.lsp.enable 'rust_analyzer'
vim.lsp.enable 'terraform_ls'

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
