local mason_path = vim.fn.stdpath 'data' .. '/mason/packages/angular-language-server/node_modules'

return {
  cmd = function(dispatchers)
    -- Find the nearest node_modules starting from the current file
    local node_modules = vim.fs.find('node_modules', { upward = true, stop = vim.env.HOME })[1]
    local root = node_modules and vim.fn.fnamemodify(node_modules, ':h') or vim.fn.getcwd()

    -- The Angular LS is picky: it often needs the path to the internal 'lib' folder
    local ng_service_path = root .. '/node_modules/@angular/language-service'

    local ts_probe = mason_path .. ',' .. root .. '/node_modules'
    local ng_probe = mason_path .. '/@angular/language-server/node_modules' .. ',' .. ng_service_path

    return vim.lsp.rpc.start({
      'ngserver',
      -- Use the full path to the mason executable if 'ngserver' isn't in your $PATH
      -- vim.fn.stdpath 'data' .. '/mason/bin/ngserver',
      '--stdio',
      '--tsProbeLocations',
      ts_probe,
      '--ngProbeLocations',
      ng_probe,
    }, dispatchers)
  end,
  filetypes = { 'typescript', 'html', 'htmlangular' },
  root_markers = { 'angular.json', 'nx.json', 'package.json' },
}
