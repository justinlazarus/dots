return {
  'seblyng/roslyn.nvim',
  ft = 'cs',
  opts = {
    exe = vim.fn.stdpath 'data' .. '/mason/bin/roslyn',
    -- Let the Roslyn server handle filewatching for better performance
    filewatching = 'roslyn',
    broad_search = false,
    lock_target = false,
    on_attach = function(client, bufnr)
      vim.notify('roslyn LSP attached: ' .. (client.name or 'unknown'), vim.log.levels.INFO)
      client.handlers['workspace/_roslyn_projectNeedsRestore'] = function(_, params, ctx)
        vim.notify('roslyn: received projectNeedsRestore request; auto-responding false', vim.log.levels.INFO)
        return { shouldRestore = false }
      end
    end,
  },
}
