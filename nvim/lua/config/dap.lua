local dap = require 'dap'
local dapui = require 'dapui'

-- Adapter
dap.adapters.coreclr = {
  type = 'executable',
  command = 'netcoredbg',
  args = { '--interpreter=vscode' },
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

-- Keymaps
local map = vim.keymap.set
map('n', '<F5>', dap.continue, { desc = 'Debug: Continue' })
map('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
map('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
map('n', '<F12>', dap.step_out, { desc = 'Debug: Step Out' })
map('n', '<leader>db', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
map('n', '<leader>dB', function()
  dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
end, { desc = 'Debug: Conditional Breakpoint' })
map('n', '<leader>dc', dap.continue, { desc = 'Debug: Continue' })
map('n', '<leader>du', dapui.toggle, { desc = 'Debug: Toggle UI' })
map('n', '<leader>dr', dap.repl.open, { desc = 'Debug: REPL' })
map('n', '<leader>dk', function()
  require('dap.ui.widgets').hover()
end, { desc = 'Debug: Hover Variable' })
