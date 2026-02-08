return {
  cmd = { 'typescript-language-server', '--stdio' },
  filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
  root_markers = { 'tsconfig.json', 'package.json', '.git' },
  init_options = {
    preferences = {
      quotePreference = 'single',
      importModuleSpecifierPreference = 'non-relative',
    },
  },
}
