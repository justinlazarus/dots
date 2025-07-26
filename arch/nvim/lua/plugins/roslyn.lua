return {
  'seblyng/roslyn.nvim',
  ft = 'cs',
  opts = {
    exe = vim.fn.stdpath('data') .. '/mason/bin/roslyn',
    filewatching = 'auto',
    broad_search = false,
    lock_target = false,
  },
}
