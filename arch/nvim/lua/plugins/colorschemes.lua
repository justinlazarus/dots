return {
  {
    'rose-pine/neovim',
    priority = 1000,
    name = 'rose-pine',
    config = function()
      require('rose-pine').setup {
        variant = 'main', -- auto, main, moon, dawn
        dark_variant = 'main',
        dim_inactive_windows = false,
        extend_background_behind_borders = true,
        
        enable = {
          terminal = true,
          legacy_highlights = true,
          migrations = true,
        },
        
        styles = {
          bold = true,
          italic = false,
          transparency = false,
        },
        
        groups = {
          border = 'muted',
          link = 'iris',
          panel = 'surface',
          
          error = 'love',
          hint = 'iris',
          info = 'foam',
          note = 'pine',
          todo = 'rose',
          warn = 'gold',
          
          git_add = 'foam',
          git_change = 'rose',
          git_delete = 'love',
          git_dirty = 'rose',
          git_ignore = 'muted',
          git_merge = 'iris',
          git_rename = 'pine',
          git_stage = 'iris',
          git_text = 'rose',
          git_untracked = 'subtle',
          
          headings = {
            h1 = 'iris',
            h2 = 'foam',
            h3 = 'rose',
            h4 = 'gold',
            h5 = 'pine',
            h6 = 'foam',
          },
        },
        
        highlight_groups = {
          ColorColumn = { bg = 'rose' },
          CursorLine = { bg = 'foam', blend = 10 },
          StatusLine = { fg = 'love', bg = 'love', blend = 10 },
          Search = { bg = 'gold', inherit = false },
          
          -- Telescope highlights
          TelescopeBorder = { fg = 'overlay', bg = 'overlay' },
          TelescopeNormal = { fg = 'subtle', bg = 'overlay' },
          TelescopeSelection = { fg = 'text', bg = 'highlight_med' },
          TelescopeSelectionCaret = { fg = 'love', bg = 'highlight_med' },
          TelescopeMultiSelection = { fg = 'text', bg = 'highlight_high' },
          
          TelescopeTitle = { fg = 'base', bg = 'love' },
          TelescopePromptTitle = { fg = 'base', bg = 'pine' },
          TelescopePreviewTitle = { fg = 'base', bg = 'iris' },
          
          TelescopePromptNormal = { fg = 'text', bg = 'surface' },
          TelescopePromptBorder = { fg = 'surface', bg = 'surface' },
        },
      }
      -- vim.api.nvim_command 'colorscheme rose-pine'
    end,
  },
  
  {
    'catppuccin/nvim',
    priority = 900,
    name = 'catppuccin',
    config = function()
      require('catppuccin').setup {
        flavour = 'mocha',
      }
      vim.api.nvim_command 'colorscheme catppuccin'
    end,
  },
  {
    'folke/tokyonight.nvim',
    priority = 900,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }
      --vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
}
