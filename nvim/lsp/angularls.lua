local mason_path = vim.fn.stdpath('data') .. '/mason/packages/angular-language-server/node_modules'

return {
  cmd = function(dispatchers)
    local root = vim.fs.root(0, 'angular.json') or vim.fn.getcwd()
    local probe = mason_path .. ',' .. root .. '/node_modules'
    return vim.lsp.rpc.start({
      'ngserver',
      '--stdio',
      '--tsProbeLocations', probe,
      '--ngProbeLocations', probe,
    }, dispatchers)
  end,
  filetypes = { 'typescript', 'html', 'htmlangular' },
  root_markers = { 'angular.json' },
}
