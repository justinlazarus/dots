-- Suppress deprecation warnings from Neovim dev builds
vim.deprecate = function() end

-- Disable all auto-starting for now, manually start via autocmd
-- vim.lsp.enable {
--   'lua_ls',
--   'ts_ls',
-- }

-- Manually start LSP servers on FileType to avoid conflicts with roslyn.nvim
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
