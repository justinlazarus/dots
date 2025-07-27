vim.lsp.enable {
  'lua_ls',
  'ts-ls',
  'roslyn',
}

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
