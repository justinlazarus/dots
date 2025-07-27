return {
  'williamboman/mason.nvim',
  dependencies = {
    'williamboman/mason-lspconfig.nvim',
  },
  config = function()
    require('mason').setup {
      registries = {
        'github:mason-org/mason-registry',
        'github:Crashdummyy/mason-registry', -- Required for Roslyn
      },
    }

    require('mason-lspconfig').setup {
      ensure_installed = {
        'lua_ls',
        -- Roslyn will be installed separately
      },
    }
  end,
}
