-- Dotnet and NX helper mappings (buffer-local for C# files inside NX projects)

local M = {}

-- No-op used by which-key placeholders (actual mappings are buffer-local functions)
function M._noop()
  -- intentionally empty
end

-- Run nx target for the project corresponding to the current buffer
local function nx_run_target(target)
  if vim.fn.executable('nx') ~= 1 and vim.fn.executable('npx') ~= 1 then
    vim.notify('nx/npx executable not found in PATH', vim.log.levels.ERROR)
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(bufnr)
  if file == '' then
    vim.notify('No file in buffer to determine project', vim.log.levels.WARN)
    return
  end
  local file_dir = vim.fn.fnamemodify(file, ':p:h')
  local proj_file = vim.fs.find('project.json', { path = file_dir, upward = true })
  if not proj_file or #proj_file == 0 then
    vim.notify('project.json not found in parent directories', vim.log.levels.WARN)
    return
  end
  local proj_path = proj_file[1]
  local proj_dir = vim.fs.dirname(proj_path)
  local project_name = vim.fn.fnamemodify(proj_dir, ':t')

  -- Try to read project.json and use its "name" if present
  local ok, lines = pcall(vim.fn.readfile, proj_path)
  if ok and lines and #lines > 0 then
    local json_text = table.concat(lines, '\n')
    local ok2, data = pcall(vim.fn.json_decode, json_text)
    if ok2 and type(data) == 'table' then
      if data.name and data.name ~= '' then
        project_name = data.name
      end
      if data.targets and type(data.targets) == 'table' and not data.targets[target] then
        vim.notify('Target "' .. target .. '" not found in project.json targets', vim.log.levels.WARN)
      end
    end
  end

  -- Find workspace root (nx.json, workspace.json, or package.json)
  local root_markers = { 'nx.json', 'workspace.json', 'package.json' }
  local workspace_root = nil
  for _, m in ipairs(root_markers) do
    local found = vim.fs.find(m, { path = proj_dir, upward = true })
    if found and #found > 0 then
      workspace_root = vim.fs.dirname(found[1])
      break
    end
  end
  if not workspace_root then
    workspace_root = proj_dir
  end

  local use_npx = vim.fn.executable('npx') == 1
  local nx_args
  if use_npx then
    nx_args = { 'npx', 'nx', 'run', project_name .. ':' .. target }
  else
    nx_args = { 'nx', 'run', project_name .. ':' .. target }
  end
  vim.notify('Running: ' .. table.concat(nx_args, ' ') .. ' (cwd: ' .. workspace_root .. ')', vim.log.levels.INFO)
  -- Open a new empty window at the bottom-right so it doesn't share buffers
  vim.cmd('botright new')
  local new_win = vim.api.nvim_get_current_win()
  -- Ensure we're in the new window/buffer before starting the terminal job
  vim.api.nvim_set_current_win(new_win)
  local term_buf = vim.api.nvim_get_current_buf()
  vim.fn.termopen(nx_args, { cwd = workspace_root })
  pcall(vim.cmd, 'startinsert')
end

-- Helper: run `dotnet restore` in the project directory for the given buffer
local function dotnet_restore_for_buf(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, file = pcall(vim.api.nvim_buf_get_name, bufnr)
  if not ok or file == '' then
    return
  end
  local file_dir = vim.fn.fnamemodify(file, ':p:h')
  local proj_file = vim.fs.find('project.json', { path = file_dir, upward = true })
  if not proj_file or #proj_file == 0 then
    vim.notify('project.json not found in parent directories', vim.log.levels.WARN)
    return
  end
  local proj_path = proj_file[1]
  local proj_dir = vim.fs.dirname(proj_path)
  vim.notify('Running: dotnet restore (cwd: ' .. proj_dir .. ')', vim.log.levels.INFO)
  vim.cmd('botright new')
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_set_current_win(new_win)
  vim.fn.termopen({ 'dotnet', 'restore' }, { cwd = proj_dir })
  pcall(vim.cmd, 'startinsert')
end

-- Set buffer-local NX mappings for buffers inside an NX project (limited to `cs` files)
local function set_nx_bufmaps(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, file = pcall(vim.api.nvim_buf_get_name, bufnr)
  if not ok or file == '' then
    return
  end
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  if ft ~= 'cs' then
    return
  end
  local file_dir = vim.fn.fnamemodify(file, ':p:h')
  local proj_file = vim.fs.find('project.json', { path = file_dir, upward = true })
  if not proj_file or #proj_file == 0 then
    return
  end
  local opts = { buffer = bufnr }
  vim.keymap.set('n', '<leader>db', function()
    nx_run_target('build')
  end, vim.tbl_extend('force', { desc = 'NX: build project for current buffer' }, opts))
  vim.keymap.set('n', '<leader>dt', function()
    nx_run_target('test')
  end, vim.tbl_extend('force', { desc = 'NX: test project for current buffer' }, opts))
  vim.keymap.set('n', '<leader>dr', function()
    dotnet_restore_for_buf(bufnr)
  end, vim.tbl_extend('force', { desc = 'dotnet: restore' }, opts))

  local wk_ok, which_key = pcall(require, 'which-key')
  if wk_ok and which_key and which_key.register then
    which_key.register({
      d = {
        name = 'dotnet',
        b = { '<cmd>lua require("config.dotnet")._noop()<CR>', 'build (nx)' },
        t = { '<cmd>lua require("config.dotnet")._noop()<CR>', 'test (nx)' },
        r = { '<cmd>lua require("config.dotnet")._noop()<CR>', 'restore (dotnet)' },
      },
    }, { prefix = '<leader>', buffer = bufnr })
  end
end

function M.setup(opts)
  opts = opts or {}
  local events = opts.events or { 'BufReadPost', 'BufNewFile', 'BufEnter' }
  vim.api.nvim_create_autocmd(events, {
    callback = function(args)
      pcall(set_nx_bufmaps, args.buf)
    end,
  })
end

return M
