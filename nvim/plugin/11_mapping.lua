-- GENERAL
vim.keymap.set("n", "<Space>", "<Nop>", { silent = true, remap = false })
vim.keymap.set("n", "-", require("mini.files").open)
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Leader mappings ============================================================
-- stylua: ignore start

-- Create global tables with information about clue groups in certain modes
-- Structure of tables is taken to be compatible with 'mini.clue'.
_G.Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>l', desc = '+LSP' },
  { mode = 'n', keys = '<Leader>L', desc = '+Lua/Log' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>r', desc = '+R' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal/Minitest' },
  { mode = 'n', keys = '<Leader>T', desc = '+Test' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },

  { mode = 'x', keys = '<Leader>l', desc = '+LSP' },
  { mode = 'x', keys = '<Leader>r', desc = '+R' },
}

-- Create `<Leader>` mappings
local nmap_leader = function(suffix, rhs, desc, opts)
  opts = opts or {}
  opts.desc = desc
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, opts)
end
local xmap_leader = function(suffix, rhs, desc, opts)
  opts = opts or {}
  opts.desc = desc
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, opts)
end

-- b is for 'buffer'
nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', '<Cmd>lua Config.new_scratch_buffer()<CR>',    'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- e is for 'explore' and 'edit'
local edit_config_file = function(filename)
  return '<Cmd>edit ' .. vim.fn.stdpath('config') .. '/plugin/' .. filename .. '<CR>'
end
nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>', 'Directory')
nmap_leader('ef', '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>', 'File directory')
nmap_leader('em', edit_config_file('20_mini.lua'), 'Mini.nvim config')
nmap_leader('ea', edit_config_file('11_mapping.lua'),'Mapping config')
nmap_leader('eo', edit_config_file('10_options.lua'),'Options config')
nmap_leader('ep', edit_config_file('21_plugins.lua'),'Plugins config')
nmap_leader('eq', '<Cmd>lua Config.toggle_quickfix()<CR>', 'Quickfix')
nmap_leader('en', '<Cmd>cnfile<CR>', 'Next file in quickfix list')
nmap_leader('ep', '<Cmd>cpfile<CR>', 'Previous file in quickfix list')

-- l is for 'LSP' (Language Server Protocol)
local formatting_cmd = '<Cmd>lua require("conform").format({ lsp_fallback = true })<CR>'
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',    'Actions')
nmap_leader('le', '<Cmd>lua vim.diagnostic.open_float()<CR>',  'Diagnostics popup')
nmap_leader('lf', formatting_cmd,                              'Format')
nmap_leader('lo', '<Cmd>lua vim.lsp.buf.hover()<CR>',          'Information')
nmap_leader('lj', '<Cmd>lua vim.diagnostic.goto_next()<CR>',   'Next diagnostic')
nmap_leader('lk', '<Cmd>lua vim.diagnostic.goto_prev()<CR>',   'Prev diagnostic')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',     'References')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',         'Rename')
nmap_leader('ld', '<Cmd>lua vim.lsp.buf.definition()<CR>',     'Definition')
nmap_leader('lD', '<Cmd>lua vim.lsp.buf.declaration()<CR>',    'Declaration')
nmap_leader('li', '<cmd>lua vim.lsp.buf.implementation()<CR>', 'Implementations')

-- f is for 'fuzzy find'
nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',                 '"/" history')
nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',                 '":" history')
nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',          'Added hunks (all)')
nmap_leader('fA', '<Cmd>Pick git_hunks path="%" scope="staged"<CR>', 'Added hunks (current)')
nmap_leader('fb', '<Cmd>Pick buffers<CR>',                           'Buffers')
nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                       'Commits (all)')
nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>',              'Commits (current)')
nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',            'Diagnostic workspace')
nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',        'Diagnostic buffer')
nmap_leader('ff', '<Cmd>Pick files<CR>',                             'Files')
nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                         'Grep live')
nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',            'Grep current word')
nmap_leader('fh', '<Cmd>Pick help<CR>',                              'Help tags')
nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                         'Highlight groups')
nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',             'Lines (all)')
nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',         'Lines (current)')
nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                         'Modified hunks (all)')
nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>',                'Modified hunks (current)')
nmap_leader('fr', '<Cmd>Pick resume<CR>',                            'Resume')
nmap_leader('fp', '<Cmd>Pick projects<CR>',                          'Projects')
nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',            'References (LSP)')
nmap_leader('fs', '<Cmd>Pick lsp scope="workspace_symbol"<CR>',      'Symbols workspace (LSP)')
nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',       'Symbols buffer (LSP)')
nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',                'Visit paths (all)')
nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                       'Visit paths (cwd)')

-- g is for git
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
nmap_leader('ga', '<Cmd>Git diff --cached<CR>',                   'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',              'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                          'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',                  'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                            'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                       'Diff buffer')
nmap_leader('gg', '<Cmd>lua Config.open_lazygit()<CR>',           'Git tab')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',               'Log')
nmap_leader('gL', '<Cmd>' .. git_log_cmd .. ' --follow -- %<CR>', 'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>',       'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',        'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at selection')
