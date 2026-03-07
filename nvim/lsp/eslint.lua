return {
  cmd = { 'vscode-eslint-language-server', '--stdio' },
  filetypes = { 'typescript', 'javascript', 'typescriptreact', 'javascriptreact', 'html', 'htmlangular' },
  root_markers = { 'eslint.config.js', 'eslint.config.mjs', '.eslintrc.json', '.eslintrc.js', 'package.json' },
  settings = {
    validate = 'on',
    format = false,
    codeActionOnSave = { enable = false },
    workingDirectories = { mode = 'auto' },
  },
}
