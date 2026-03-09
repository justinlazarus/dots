local dap = require 'dap'
local dapui = require 'dapui'

-- Adapter
dap.adapters.coreclr = {
  type = 'executable',
  command = 'netcoredbg',
  args = { '--interpreter=vscode' },
  options = {
    detached = false,
  },
}

-- C# launch config
dap.configurations.cs = {
  {
    type = 'coreclr',
    name = 'Launch',
    request = 'launch',
    program = function()
      local cwd = vim.fn.getcwd()
      -- Try to find a dll in the default debug output
      local dlls = vim.fn.glob(cwd .. '/bin/Debug/**/**.dll', false, true)
      if #dlls > 0 then
        return vim.fn.input('Path to dll: ', dlls[1], 'file')
      end
      return vim.fn.input('Path to dll: ', cwd .. '/bin/Debug/', 'file')
    end,
  },
  {
    type = 'coreclr',
    name = 'Attach',
    request = 'attach',
    processId = function()
      return require('dap.utils').pick_process { filter = 'dotnet' }
    end,
    cwd = function()
      return vim.fn.getcwd()
    end,
    justMyCode = false,
    stopAtEntry = false,
  },
  {
    type = 'coreclr',
    name = 'Attach to Shipping API',
    request = 'attach',
    processId = 41442, -- The PID we found running
    cwd = '/Users/jlazarus/work/repos/1400196-close-load/intl-depot/apps/Costco.I18N.Depot.Shipping.Api',
    justMyCode = false,
    stopAtEntry = false,
  },
}

-- DAP UI
dapui.setup()

dap.listeners.after.event_initialized['dapui_config'] = function()
  dapui.open()
end
dap.listeners.before.event_terminated['dapui_config'] = function()
  dapui.close()
end
dap.listeners.before.event_exited['dapui_config'] = function()
  dapui.close()
end

