local mason_bin = vim.fn.stdpath('data') .. '/mason/bin/roslyn'

local cmd = {
  mason_bin,
  '--logLevel=Information',
  '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.get_log_path()),
  '--stdio',
}

return {
  cmd = cmd,
  filetypes = { 'cs' },
}
