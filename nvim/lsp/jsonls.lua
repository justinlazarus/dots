return {
  cmd = { 'vscode-json-language-server', '--stdio' },
  filetypes = { 'json' },
  root_markers = { 'package.json', '.git' },
  init_options = {
    provideFormatter = true,
  },
}
