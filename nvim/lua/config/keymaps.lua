local map = vim.keymap.set

-- ── General ──────────────────────────────────────────────────────────
map('n', '<Esc>', '<cmd>nohlsearch<CR>')
map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- ── Windows ──────────────────────────────────────────────────────────
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Focus left window' })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Focus right window' })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Focus lower window' })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Focus upper window' })

-- ── Top-level shortcuts ──────────────────────────────────────────────
map('n', '<leader><space>', function() Snacks.picker.files() end, { desc = 'Find files' })
map('n', '<leader>,', function() Snacks.picker.buffers() end, { desc = 'Buffers' })
map('n', '<leader>/', function() Snacks.picker.grep() end, { desc = 'Grep' })
map('n', '<leader>:', function() Snacks.picker.command_history() end, { desc = 'Command history' })
map('n', '<leader>n', function() Snacks.picker() end, { desc = 'All pickers' })
map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Diagnostics to loclist' })

-- ── Files (open by name/path) ────────────────────────────────────────
map('n', '<leader>fe', '<cmd>Oil<CR>', { desc = 'Explorer' })
map('n', '<leader>ff', function() Snacks.picker.files() end, { desc = 'Find files' })
map('n', '<leader>fc', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, { desc = 'Config files' })
map('n', '<leader>fg', function() Snacks.picker.git_files() end, { desc = 'Git files' })
map('n', '<leader>fr', function() Snacks.picker.recent() end, { desc = 'Recent files' })
map('n', '<leader>fp', function()
  local path = vim.fn.expand '%:p'
  vim.fn.setreg('+', path)
  Snacks.notify.info('Copied: ' .. path)
end, { desc = 'Copy file path' })
map('n', '<leader>fn', function()
  local name = vim.fn.expand '%:t'
  vim.fn.setreg('+', name)
  Snacks.notify.info('Copied: ' .. name)
end, { desc = 'Copy file name' })

-- ── Search (content, metadata, pickers) ──────────────────────────────
map('n', '<leader>sg', function() Snacks.picker.grep() end, { desc = 'Grep' })
map({ 'n', 'x' }, '<leader>sw', function() Snacks.picker.grep_word() end, { desc = 'Grep word/selection' })
map('n', '<leader>sb', function() Snacks.picker.lines() end, { desc = 'Buffer lines' })
map('n', '<leader>sB', function() Snacks.picker.grep_buffers() end, { desc = 'Grep open buffers' })
map('n', '<leader>sd', function() Snacks.picker.diagnostics() end, { desc = 'Diagnostics' })
map('n', '<leader>sD', function() Snacks.picker.diagnostics_buffer() end, { desc = 'Buffer diagnostics' })
map('n', '<leader>ss', function() Snacks.picker.lsp_symbols() end, { desc = 'Document symbols' })
map('n', '<leader>sS', function() Snacks.picker.lsp_workspace_symbols() end, { desc = 'Workspace symbols' })
map('n', '<leader>sh', function() Snacks.picker.help() end, { desc = 'Help pages' })
map('n', '<leader>sH', function() Snacks.picker.highlights() end, { desc = 'Highlights' })
map('n', '<leader>sk', function() Snacks.picker.keymaps() end, { desc = 'Keymaps' })
map('n', '<leader>sm', function() Snacks.picker.marks() end, { desc = 'Marks' })
map('n', '<leader>sM', function() Snacks.picker.man() end, { desc = 'Man pages' })
map('n', '<leader>sj', function() Snacks.picker.jumps() end, { desc = 'Jumps' })
map('n', '<leader>sq', function() Snacks.picker.qflist() end, { desc = 'Quickfix list' })
map('n', '<leader>sl', function() Snacks.picker.loclist() end, { desc = 'Location list' })
map('n', '<leader>sR', function() Snacks.picker.resume() end, { desc = 'Resume last picker' })
map('n', '<leader>su', function() Snacks.picker.undo() end, { desc = 'Undo history' })
map('n', '<leader>s"', function() Snacks.picker.registers() end, { desc = 'Registers' })
map('n', '<leader>s/', function() Snacks.picker.search_history() end, { desc = 'Search history' })
map('n', '<leader>sa', function() Snacks.picker.autocmds() end, { desc = 'Autocmds' })
map('n', '<leader>sc', function() Snacks.picker.commands() end, { desc = 'Commands' })

-- ── Git ──────────────────────────────────────────────────────────────
map('n', '<leader>gs', function() Snacks.picker.git_status() end, { desc = 'Status' })
map('n', '<leader>gb', function() Snacks.picker.git_branches() end, { desc = 'Branches' })
map('n', '<leader>gl', function() Snacks.picker.git_log() end, { desc = 'Log' })
map('n', '<leader>gL', function() Snacks.picker.git_log_line() end, { desc = 'Log (line)' })
map('n', '<leader>gf', function() Snacks.picker.git_log_file() end, { desc = 'Log (file)' })
map('n', '<leader>gd', function() Snacks.picker.git_diff() end, { desc = 'Diff hunks' })
map('n', '<leader>gS', function() Snacks.picker.git_stash() end, { desc = 'Stash' })

-- ── LSP ──────────────────────────────────────────────────────────────
map('n', 'gd', function() Snacks.picker.lsp_definitions() end, { desc = 'Definition' })
map('n', 'gD', function() Snacks.picker.lsp_declarations() end, { desc = 'Declaration' })
map('n', 'grr', function() Snacks.picker.lsp_references() end, { nowait = true, desc = 'References' })
map('n', 'gri', function() Snacks.picker.lsp_implementations() end, { desc = 'Implementation' })
map('n', 'gy', function() Snacks.picker.lsp_type_definitions() end, { desc = 'Type definition' })
map({ 'n', 'v' }, 'gra', vim.lsp.buf.code_action, { desc = 'Code action' })
map({ 'n', 'i' }, '<C-s>', function() vim.lsp.buf.signature_help() end, { desc = 'Signature help' })

-- ── Debug ────────────────────────────────────────────────────────────
local dap = require 'dap'
local dapui = require 'dapui'
map('n', '<F5>', dap.continue, { desc = 'Continue' })
map('n', '<F10>', dap.step_over, { desc = 'Step over' })
map('n', '<F11>', dap.step_into, { desc = 'Step into' })
map('n', '<F12>', dap.step_out, { desc = 'Step out' })
map('n', '<leader>db', dap.toggle_breakpoint, { desc = 'Toggle breakpoint' })
map('n', '<leader>dB', function()
  dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = 'Conditional breakpoint' })
map('n', '<leader>dc', dap.continue, { desc = 'Continue' })
map('n', '<leader>du', dapui.toggle, { desc = 'Toggle UI' })
map('n', '<leader>dr', dap.repl.open, { desc = 'REPL' })
map('n', '<leader>dk', function()
  require('dap.ui.widgets').hover()
end, { desc = 'Hover variable' })

-- ── Toggle ───────────────────────────────────────────────────────────
map('n', '<leader>uh', function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = 'Toggle inlay hints' })
map('n', '<leader>uC', function() Snacks.picker.colorschemes() end, { desc = 'Colorschemes' })

-- ── NX ───────────────────────────────────────────────────────────────
map('n', '<leader>ox', function() require('config.nx').pick() end, { desc = 'NX: pick target' })
map('n', '<leader>ob', function() require('config.nx').run('build') end, { desc = 'NX: build project' })
map('n', '<leader>ot', function() require('config.nx').run('test') end, { desc = 'NX: test project' })
map('n', '<leader>ol', function() require('config.nx').show_output() end, { desc = 'NX: last output' })

-- ── Commands ─────────────────────────────────────────────────────────
vim.api.nvim_create_user_command('UpdateAll', function()
  print 'Updating plugins...'
  vim.pack.update()
  local ok, ts_install = pcall(require, 'nvim-treesitter.install')
  if ok then
    print 'Updating Treesitter parsers...'
    ts_install.update { with_sync = true }
  end
  print 'Update complete!'
end, { desc = 'Update plugins and Treesitter parsers' })
