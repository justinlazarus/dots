-- Dotnet and NX helper mappings (buffer-local for C# files inside NX projects)

local M = {}

local function find_workspace_root(start_dir)
  start_dir = start_dir or vim.fn.getcwd()
  for _, marker in ipairs { 'nx.json', 'workspace.json', 'package.json' } do
    local found = vim.fs.find(marker, { path = start_dir, upward = true })
    if found and #found > 0 then
      return vim.fs.dirname(found[1])
    end
  end
  return nil
end

local function nx_bin()
  if vim.fn.executable 'nx' == 1 then
    return 'nx'
  elseif vim.fn.executable 'npx' == 1 then
    return 'npx nx'
  end
  return nil
end

local function run_nx_cmd(cmd, cwd)
  vim.notify('Running: ' .. cmd, vim.log.levels.INFO)
  vim.cmd 'botright new'
  vim.fn.termopen(vim.o.shell .. ' -c ' .. vim.fn.shellescape(cmd), { cwd = cwd })
  pcall(vim.cmd, 'startinsert')
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

  local workspace_root = find_workspace_root(proj_dir)

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

  -- Use shell to ensure proper PATH is loaded
  local shell_cmd = table.concat(nx_args, ' ')
  vim.fn.termopen(vim.o.shell .. ' -c ' .. vim.fn.shellescape(shell_cmd), { cwd = workspace_root })
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
  vim.keymap.set('n', '<leader>ob', function()
    nx_run_target('build')
  end, vim.tbl_extend('force', { desc = 'NX: build project' }, opts))
  vim.keymap.set('n', '<leader>ot', function()
    nx_run_target('test')
  end, vim.tbl_extend('force', { desc = 'NX: test project' }, opts))
  vim.keymap.set('n', '<leader>or', function()
    dotnet_restore_for_buf(bufnr)
  end, vim.tbl_extend('force', { desc = 'dotnet: restore' }, opts))
end

function M.nx_picker()
  local bin = nx_bin()
  if not bin then
    vim.notify('nx/npx executable not found in PATH', vim.log.levels.ERROR)
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == '' then
    vim.notify('No file in buffer to determine project', vim.log.levels.WARN)
    return
  end

  local file_dir = vim.fn.fnamemodify(file, ':p:h')
  local workspace_root = find_workspace_root(file_dir)
  if not workspace_root then
    vim.notify('Not in an Nx workspace (nx.json not found)', vim.log.levels.WARN)
    return
  end

  local icons = {
    build = { ' ', 'DiagnosticOk' },
    test = { ' ', 'DiagnosticInfo' },
    lint = { '󱄽 ', 'DiagnosticWarn' },
    format = { ' ', 'DiagnosticHint' },
  }
  local default_icon = { ' ', 'NonText' }

  local items = {}

  -- Project-local targets from nearest project.json
  local proj_file = vim.fs.find('project.json', { path = file_dir, upward = true })
  if proj_file and #proj_file > 0 then
    local ok, lines = pcall(vim.fn.readfile, proj_file[1])
    if ok and lines and #lines > 0 then
      local ok2, data = pcall(vim.fn.json_decode, table.concat(lines, '\n'))
      if ok2 and type(data) == 'table' then
        local proj_dir = vim.fs.dirname(proj_file[1])
        local project_name = data.name or vim.fn.fnamemodify(proj_dir, ':t')
        if data.targets and type(data.targets) == 'table' then
          for target_name, _ in pairs(data.targets) do
            local full_cmd = bin .. ' run ' .. project_name .. ':' .. target_name
            table.insert(items, {
              text = project_name .. ':' .. target_name,
              target = target_name,
              cmd = full_cmd,
              preview = { text = full_cmd, ft = 'sh' },
            })
          end
        end
      end
    end
  end

  -- Global run-many targets (always at the bottom)
  for _, t in ipairs { 'build', 'format', 'lint', 'test' } do
    local full_cmd = bin .. ' run-many -t ' .. t
    table.insert(items, {
      text = 'run-many -t ' .. t,
      target = t,
      cmd = full_cmd,
      preview = { text = full_cmd, ft = 'sh' },
    })
  end

  Snacks.picker({
    title = 'Run Nx Targets',
    items = items,
    preview = 'preview',
    format = function(item)
      local icon = icons[item.target] or default_icon
      return {
        { icon[1], icon[2] },
        { ' ' },
        { item.text },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      run_nx_cmd(item.cmd, workspace_root)
    end,
  })
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
