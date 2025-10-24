local mason_bin = vim.fn.stdpath('data') .. '/mason/bin/roslyn'
local cmd = nil

if vim.fn.executable(mason_bin) == 1 then
  cmd = {
    mason_bin,
    '--logLevel=Information',
    '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.get_log_path()),
    '--stdio',
  }
else
  local dll = vim.env.ROSLYN_DLL or vim.fn.expand('~/dots/roslyn/Microsoft.CodeAnalysis.LanguageServer.dll')
  if vim.loop.fs_stat(dll) then
    cmd = {
      'dotnet',
      dll,
      '--logLevel=Information',
      '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.get_log_path()),
      '--stdio',
    }
  end
end

return {
  cmd = cmd,
  filetypes = { 'cs' },
}
