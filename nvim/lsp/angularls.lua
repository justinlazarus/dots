local mason_path = vim.fn.stdpath('data') .. '/mason/packages/angular-language-server/node_modules'

return {
  cmd = {
    'ngserver',
    '--stdio',
    '--tsProbeLocations', mason_path,
    '--ngProbeLocations', mason_path,
  },
  filetypes = { 'typescript', 'html', 'htmlangular' },
  root_markers = { 'angular.json' },
}
