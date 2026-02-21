-- 1. Load the plugin
vim.pack.add {
  'https://github.com/folke/snacks.nvim.git',
}

_G.Snacks = require 'snacks'

Snacks.setup {
  picker = {
    enabled = true,
    ui_select = true,
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
  -- Enable all other "Snacks"
  bigfile = { enabled = true },
  dashboard = { enabled = true },
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  quickfile = { enabled = true },
  scroll = { enabled = false },
  statuscolumn = { enabled = true },
  words = { enabled = true },
}

local map = vim.keymap.set

-- Top Pickers & Explorer
map('n', '<leader><space>', function()
  Snacks.picker.files()
end, { desc = 'Smart Find Files' })
map('n', '<leader>,', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
map('n', '<leader>/', function()
  Snacks.picker.grep()
end, { desc = 'Grep' })
map('n', '<leader>:', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
map('n', '<leader>n', function()
  Snacks.picker()
end, { desc = 'All Pickers' })

-- Find
map('n', '<leader>fb', function()
  Snacks.picker.buffers()
end, { desc = 'Buffers' })
map('n', '<leader>fc', function()
  Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
end, { desc = 'Find Config File' })
map('n', '<leader>ff', function()
  Snacks.picker.files()
end, { desc = 'Find Files' })
map('n', '<leader>fg', function()
  Snacks.picker.git_files()
end, { desc = 'Find Git Files' })
map('n', '<leader>fr', function()
  Snacks.picker.recent()
end, { desc = 'Recent' })

-- Git
map('n', '<leader>gb', function()
  Snacks.picker.git_branches()
end, { desc = 'Git Branches' })
map('n', '<leader>gl', function()
  Snacks.picker.git_log()
end, { desc = 'Git Log' })
map('n', '<leader>gL', function()
  Snacks.picker.git_log_line()
end, { desc = 'Git Log Line' })
map('n', '<leader>gs', function()
  Snacks.picker.git_status()
end, { desc = 'Git Status' })
map('n', '<leader>gS', function()
  Snacks.picker.git_stash()
end, { desc = 'Git Stash' })
map('n', '<leader>gd', function()
  Snacks.picker.git_diff()
end, { desc = 'Git Diff (Hunks)' })
map('n', '<leader>gf', function()
  Snacks.picker.git_log_file()
end, { desc = 'Git Log File' })

-- Search & Grep
map('n', '<leader>sb', function()
  Snacks.picker.lines()
end, { desc = 'Buffer Lines' })
map('n', '<leader>sB', function()
  Snacks.picker.grep_buffers()
end, { desc = 'Grep Open Buffers' })
map('n', '<leader>sg', function()
  Snacks.picker.grep()
end, { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', function()
  Snacks.picker.grep_word()
end, { desc = 'Visual selection or word' })

-- Search Helpers
map('n', '<leader>s"', function()
  Snacks.picker.registers()
end, { desc = 'Registers' })
map('n', '<leader>s/', function()
  Snacks.picker.search_history()
end, { desc = 'Search History' })
map('n', '<leader>sa', function()
  Snacks.picker.autocmds()
end, { desc = 'Autocmds' })
map('n', '<leader>sc', function()
  Snacks.picker.command_history()
end, { desc = 'Command History' })
map('n', '<leader>sC', function()
  Snacks.picker.commands()
end, { desc = 'Commands' })
map('n', '<leader>sd', function()
  Snacks.picker.diagnostics()
end, { desc = 'Diagnostics' })
map('n', '<leader>sD', function()
  Snacks.picker.diagnostics_buffer()
end, { desc = 'Buffer Diagnostics' })
map('n', '<leader>sh', function()
  Snacks.picker.help()
end, { desc = 'Help Pages' })
map('n', '<leader>sH', function()
  Snacks.picker.highlights()
end, { desc = 'Highlights' })
map('n', '<leader>sj', function()
  Snacks.picker.jumps()
end, { desc = 'Jumps' })
map('n', '<leader>sk', function()
  Snacks.picker.keymaps()
end, { desc = 'Keymaps' })
map('n', '<leader>sl', function()
  Snacks.picker.loclist()
end, { desc = 'Location List' })
map('n', '<leader>sm', function()
  Snacks.picker.marks()
end, { desc = 'Marks' })
map('n', '<leader>sM', function()
  Snacks.picker.man()
end, { desc = 'Man Pages' })
map('n', '<leader>sq', function()
  Snacks.picker.qflist()
end, { desc = 'Quickfix List' })
map('n', '<leader>sR', function()
  Snacks.picker.resume()
end, { desc = 'Resume' })
map('n', '<leader>su', function()
  Snacks.picker.undo()
end, { desc = 'Undo / Change List' })
map('n', '<leader>uC', function()
  Snacks.picker.colorschemes()
end, { desc = 'Colorschemes' })

-- Nx
map('n', '<leader>ox', function()
  require('config.dotnet').nx_picker()
end, { desc = 'NX: pick target' })

-- LSP pickers
map('n', 'gd', function()
  Snacks.picker.lsp_definitions()
end, { desc = 'Goto Definition' })
map('n', 'gD', function()
  Snacks.picker.lsp_declarations()
end, { desc = 'Goto Declaration' })
map('n', 'grr', function()
  Snacks.picker.lsp_references()
end, { nowait = true, desc = 'References' })
map('n', 'gri', function()
  Snacks.picker.lsp_implementations()
end, { desc = 'Goto Implementation' })
map('n', 'gy', function()
  Snacks.picker.lsp_type_definitions()
end, { desc = 'Goto Type Definition' })
map('n', '<leader>ss', function()
  Snacks.picker.lsp_symbols()
end, { desc = 'LSP Symbols' })
map('n', '<leader>sS', function()
  Snacks.picker.lsp_workspace_symbols()
end, { desc = 'LSP Workspace Symbols' })
