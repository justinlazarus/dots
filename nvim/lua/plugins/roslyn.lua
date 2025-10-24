return {
  'seblyng/roslyn.nvim',
  ft = 'cs',
  opts = {
    exe = vim.fn.stdpath 'data' .. '/mason/bin/roslyn',
    -- Let the Roslyn server handle filewatching for better performance
    filewatching = 'roslyn',
    broad_search = false,
    lock_target = false,
  },
}
