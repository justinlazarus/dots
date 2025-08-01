return {

  {
    'rose-pine/neovim',
    priority = 1000,
    name = 'rose-pine',
    config = function()
      require('rose-pine').setup {
        variant = 'main',
        styles = {
          transparency = false,
        },
        dark_variant = 'main',
        bold_vert_split = false,
        dim_nc_background = false,
        disable_background = false,
        disable_float_background = false,
      }
      --vim.api.nvim_command 'colorscheme rose-pine'
    end,
  },
  {
    'catppuccin/nvim',
    priority = 999,
    name = 'catppuccin',
    config = function()
      require('catppuccin').setup {
        flavour = 'mocha',
        transparent_background = true,
      }
      -- vim.api.nvim_command 'colorscheme catppuccin'
    end,
  },
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },
}
