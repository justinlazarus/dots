vim.lsp.enable {
  'lua_ls',
  'ts_ls',
}

-- When an LSP attaches, set buffer-local keymaps for code actions
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local bufnr = args.buf
    local opts = { buffer = bufnr }
    vim.keymap.set('n', '<leader>ca', function()
      local f = (vim.lsp and vim.lsp.buf and vim.lsp.buf.code_action)
      if type(f) == 'function' then
        f()
      else
        vim.notify('LSP code_action not available', vim.log.levels.WARN)
      end
    end, vim.tbl_extend('force', { desc = 'Code Action' }, opts))

    vim.keymap.set('v', '<leader>ca', function()
      local f = (vim.lsp and vim.lsp.buf and vim.lsp.buf.range_code_action) or (vim.lsp and vim.lsp.buf and vim.lsp.buf.code_action)
      if type(f) == 'function' then
        f()
      else
        vim.notify('LSP range/code_action not available', vim.log.levels.WARN)
      end
    end, vim.tbl_extend('force', { desc = 'Range Code Action' }, opts))
  end,
})

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
