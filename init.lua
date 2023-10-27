
---------------------------------------------------------------------------------------------------
-- plugin configuration ---------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
local lsp_zero = require('lsp-zero')
local cmp = require('cmp')
local lspcfg = require('lspconfig')
local cmp_action = require('lsp-zero').cmp_action()
local cmp_select = {behavior = cmp.SelectBehavior.Select}

require('hardtime').setup()

-- status line
require('lualine').setup{ options = { theme = 'onedark' } }

-- mason language server manager
require("mason").setup({ PATH = "prepend" })

lsp_zero.on_attach(function(_, bufnr)
  lsp_zero.default_keymaps({buffer = bufnr})
end)

-- language server style
vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
  vim.lsp.handlers.hover,
  {border = 'rounded'}
)

vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
  vim.lsp.handlers.signature_help,
  {border = 'rounded'}
)

-- LUA language server
lspcfg.lua_ls.setup({
  settings = {
    Lua = {
      diagnostics = {
        globals = { 'vim' }
      }
    }
  }
});

-- C# language server
lspcfg.omnisharp.setup({
  cmd = { "omnisharp", "--languageserver", "--hostPID", tostring(vim.fn.getpid()) }
});

-- Completion Engine
cmp.setup({
  sources = {
    {name = 'path'},
    {name = 'nvim_lsp'},
    {name = 'nvim_lua'},
  },
  mapping = cmp.mapping.preset.insert({


    -- Enter key confirms completion
    ['<CR>'] = cmp.mapping.confirm({ select = true }),

    -- Ctrl+Space triggers completion
    ["<C-Space>"] = cmp.mapping.complete(),

    -- Navigation
    ['<C-f>'] = cmp_action.luasnip_jump_forward(),
    ['<C-b>'] = cmp_action.luasnip_jump_backward(),

    ['<C-j>'] = cmp.mapping.select_next_item(cmp_select),
    ['<C-k>'] = cmp.mapping.select_prev_item(cmp_select),

    ['<C-u>'] = cmp.mapping.scroll_docs(-4),
    ['<C-d>'] = cmp.mapping.scroll_docs(4),
  })
})

---------------------------------------------------------------------------------------------------
-- vim sets ---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
vim.opt.nu = true
vim.opt.relativenumber = true

vim.tabstop = 4
vim.softtabstop = 4
vim.shiftwidth = 4
vim.expandtab = true
vim.textwidth = 80

vim.opt.wrap = false

vim.swapfile = false
vim.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = "100"

---------------------------------------------------------------------------------------------------
-- key maps ---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- fugitive
vim.keymap.set("n", "<leader>gs", vim.cmd.Git);

-- netrw
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

-- telescope
local bi = require('telescope.builtin')
pcall(require('telescope').load_extension, 'fzf')
vim.keymap.set('n', '<leader>?', bi.oldfiles, { desc = '[?] Find recently opened files' })
vim.keymap.set('n', '<leader><space>', bi.buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>gf', bi.git_files, { desc = 'Search [G]it [F]iles' })
vim.keymap.set('n', '<leader>sf', bi.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sh', bi.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sw', bi.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', bi.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', bi.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', bi.resume, { desc = '[S]earch [R]esume' })

vim.keymap.set('n', '<leader>/', function()
  bi.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })

---------------------------------------------------------------------------------------------------
-- syntax highlight -------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
require'nvim-treesitter.configs'.setup {
  ensure_installed = {
	  "javascript",
	  "typescript",
	  "c",
	  "c_sharp",
	  "lua",
	  "vim",
	  "vimdoc",
	  "query",
	  "rust",
  },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
    enable = true,

    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}

---------------------------------------------------------------------------------------------------
-- plugin management ------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
  use 'wbthomason/packer.nvim'
  use('nvim-treesitter/nvim-treesitter', { run = ':TSUpdate' })
  use('tpope/vim-fugitive')

  use {
    'navarasu/onedark.nvim',
    priority = 1000,
    config = function() vim.cmd.colorscheme 'onedark' end,
  }

  use {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.4',
    requires = { {'nvim-lua/plenary.nvim'} }
  }

  use {
    'nvim-lualine/lualine.nvim',
    opts = {
      icons_enabled = false,
      theme = 'onedark',
      component_separators = '|',
      section_separators = '',
      }
  }

  use {
    'm4xshen/hardtime.nvim',
    requires = {
      {'MunifTanjim/nui.nvim'},
      {'nvim-lua/plenary.nvim'},
    }
  }


  use {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    requires = {
      {'williamboman/mason.nvim'},
      {'williamboman/mason-lspconfig.nvim'},
      {'neovim/nvim-lspconfig'},
      {'hrsh7th/nvim-cmp'},
      {'hrsh7th/cmp-nvim-lsp'},
      {'L3MON4D3/LuaSnip'},
      }
  }
end)
