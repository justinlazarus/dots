-- Suppress deprecation warnings from Neovim dev builds
vim.deprecate = function() end

-- Manually start LSP servers on FileType
-- (Not using vim.lsp.enable to avoid conflicts with roslyn.nvim's custom setup)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'lua',
  callback = function(args)
    vim.lsp.start({
      name = 'lua_ls',
      cmd = { vim.fn.stdpath('data') .. '/mason/bin/lua-language-server' },
      root_dir = vim.fs.root(args.buf, {'.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml', '.git'}),
    })
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = {'javascript', 'javascriptreact', 'typescript', 'typescriptreact'},
  callback = function(args)
    vim.lsp.start({
      name = 'ts_ls',
      cmd = { vim.fn.stdpath('data') .. '/mason/bin/typescript-language-server', '--stdio' },
      root_dir = vim.fs.root(args.buf, {'package.json', 'tsconfig.json', 'jsconfig.json', '.git'}),
    })
  end,
})

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
