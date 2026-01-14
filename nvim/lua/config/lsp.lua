-- When an LSP attaches, set buffer-local keymaps for code actions
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
    vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, { buffer = args.buf, desc = 'Code Action' })
  end,
})

-- Custom function to find the project root directory
-- Searches up from the current buffer's path for the first matching file/directory
local function find_root_dir(file_patterns)
  -- Start searching from the directory of the current buffer
  local cwd = vim.fn.expand '%:p:h'
  
  for _, pattern in ipairs(file_patterns) do
    local root = vim.fn.findfile(pattern, cwd .. ';')
    if root and root ~= '' then
      return vim.fn.fnamemodify(root, ':h')
    end
    root = vim.fn.finddir(pattern, cwd .. ';')
    if root and root ~= '' and root ~= '.' then
      return root
    end
  end
  
  -- Fallback to current working directory if no specific root pattern is found
  return cwd
end

-- Define a global on_attach function
local on_attach_callback = function(client, bufnr)
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr, desc = 'Code Action' })
  vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr, desc = 'Code Action' })
end

-- Use vim.lsp.config() to define the configurations for each server

-- 1. lua_ls configuration
vim.lsp.config('lua_ls', {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  root_dir = function(fname)
    return find_root_dir { '.git', '.nvim', '.luarc.json' }
  end,
  on_attach = on_attach_callback,
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
})

-- 2. tsserver configuration (TypeScript/JavaScript)
vim.lsp.config('tsserver', {
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
  root_dir = function(fname)
    return find_root_dir { 'package.json', 'tsconfig.json', '.git' }
  end,
  on_attach = on_attach_callback,
  init_options = {
    preferences = {
      quotePreference = 'single',
      importModuleSpecifierPreference = 'non-relative',
    },
  },
})

-- 3. jsonls configuration
vim.lsp.config('jsonls', {
  cmd = { 'vscode-json-language-server', '--stdio' },
  filetypes = { 'json' },
  root_dir = function(fname)
    return find_root_dir { 'package.json', 'composer.json', '.git' }
  end,
  on_attach = on_attach_callback,
  init_options = {
    provideFormatter = true,
  },
})

-- 4. angularls configuration
vim.lsp.config('angularls', {
  cmd = { 'ngserver', '--stdio' },
  filetypes = { 'typescript', 'html' },
  root_dir = function(fname)
    return find_root_dir { 'angular.json', 'package.json', '.git' }
  end,
  on_attach = on_attach_callback,
})

-- Enable all the defined configurations for automatic start (using the corrected syntax)
vim.lsp.enable 'lua_ls'
vim.lsp.enable 'tsserver'
vim.lsp.enable 'jsonls'
vim.lsp.enable 'angularls'

vim.diagnostic.config {
  virtual_lines = false,
  virtual_text = true,
  underline = true,
}
