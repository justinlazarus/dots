return {

  {
    'p00f/alabaster.nvim',
    priority = 1001,
    name = 'alabaster',
    -- Don't auto-apply Alabaster so it won't override the chosen default colorscheme
    config = function()
      -- intentionally left blank
    end,
  },


  {
    'rose-pine/neovim',
    priority = 1000,
    name = 'rose-pine',
    config = function()
      local ok, rp = pcall(require, 'rose-pine')
      if not ok then
        vim.notify('rose-pine not loaded: ' .. tostring(rp), vim.log.levels.WARN)
        return
      end
      if type(rp.setup) == 'function' then
        rp.setup {
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
      end
      --vim.api.nvim_command 'colorscheme rose-pine'
    end,
  },
  {
    'catppuccin/nvim',
    priority = 1001,
    name = 'catppuccin',
    config = function()
      local ok, cp = pcall(require, 'catppuccin')
      if not ok then
        vim.notify('catppuccin not loaded: ' .. tostring(cp), vim.log.levels.WARN)
        return
      end
      if type(cp.setup) == 'function' then
        cp.setup {
          flavour = 'mocha',
          transparent_background = false,
        }
      end
      -- Do not auto-apply Catppuccin; user selected Tokyonight
    end,
  },
  {
    'folke/tokyonight.nvim',
    priority = 1003,
    config = function()
      local ok, tt = pcall(require, 'tokyonight')
      if not ok then
        vim.notify('tokyonight not loaded: ' .. tostring(tt), vim.log.levels.WARN)
        return
      end
      ---@diagnostic disable-next-line: missing-fields
      if type(tt.setup) == 'function' then
        tt.setup {
          style = 'storm',
          styles = {
            comments = { italic = false },
          },
        }
      end
      pcall(vim.cmd, 'colorscheme tokyonight')
    end,
  },
}
