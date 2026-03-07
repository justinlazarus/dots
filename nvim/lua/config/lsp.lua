vim.lsp.enable { 'lua_ls', 'ts_ls', 'jsonls', 'yamlls', 'angularls', 'rust_analyzer', 'terraform_ls', 'gopls' }

vim.api.nvim_create_user_command('LspLog', function()
  vim.cmd.edit(vim.lsp.log.get_filename())
end, { desc = 'Open LSP log file' })

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}

-- Map 'csharp' language tag to c_sharp treesitter parser (for hover code blocks)
vim.treesitter.language.register('c_sharp', 'csharp')

-- Rounded borders on hover and signature help
vim.o.winborder = 'rounded'

-- Wrap bare Roslyn hover signatures in fenced code blocks for treesitter highlighting
vim.lsp.handlers['textDocument/hover'] = function(err, result, ctx, config)
  if result and result.contents then
    local contents = result.contents
    if type(contents) == 'table' and contents.kind == 'markdown' and contents.value then
      local val = contents.value
      if not val:match('```') then
        local sig, rest = val:match('^(.-)\n\n(.*)')
        if sig then
          result.contents.value = '```csharp\n' .. sig .. '\n```\n\n' .. rest
        else
          result.contents.value = '```csharp\n' .. val .. '\n```'
        end
      end
    end
  end
  return vim.lsp.handlers.hover(err, result, ctx, config)
end
