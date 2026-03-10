vim.pack.add {
  'https://github.com/folke/snacks.nvim.git',
}

_G.Snacks = require 'snacks'

Snacks.setup {
  picker = {
    enabled = true,
    ui_select = false,
    win = {
      input = {
        keys = {
          -- Workaround for Neovim 0.12-dev prompt buffer regression
          -- where backspace can't delete the first character
          ['<BS>'] = {
            function(self)
              local win = vim.api.nvim_get_current_win()
              local buf = vim.api.nvim_win_get_buf(win)
              local col = vim.api.nvim_win_get_cursor(win)[2]
              if col == 0 then return end
              local line = (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or '')
              local new_line = line:sub(1, col - 1) .. line:sub(col + 1)
              vim.api.nvim_buf_set_lines(buf, 0, -1, false, { new_line })
              vim.api.nvim_win_set_cursor(win, { 1, col - 1 })
            end,
            mode = { 'i' },
            desc = 'backspace (fix prompt buffer)',
          },
        },
      },
    },
    layout = {
      layout = {
        box = 'horizontal',
        width = 0.95,
        height = 0.95,
        {
          box = 'vertical',
          border = 'rounded',
          title = '{title} {stats}',
          title_pos = 'center',
          { win = 'input', height = 1, border = 'bottom' },
          { win = 'list', border = 'none' },
        },
        {
          win = 'preview',
          title = '{preview}',
          border = 'rounded',
          width = 0.60,
        },
      },
    },
    formatters = {
      file = { filename_first = true },
    },
  },
  bigfile = { enabled = true },
  dashboard = {
    enabled = true,
    sections = {
      { section = 'header' },
      { section = 'keys', gap = 1, padding = 1 },
      { section = 'recent_files', title = 'Recent Files', padding = 1 },
      { section = 'projects', title = 'Projects', padding = 1 },
    },
  },
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = true },
  words = { enabled = true },
}
