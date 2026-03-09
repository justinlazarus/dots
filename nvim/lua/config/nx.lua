local M = {}

-- Last run output (raw lines with ANSI codes preserved)
local last_output_lines = {}

--- Find the NX workspace root by searching upward for nx.json.
---@param path? string starting directory (defaults to current buffer's directory)
---@return string? root
local function find_workspace(path)
  path = path or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:h')
  local found = vim.fs.find('nx.json', { path = path, upward = true })
  if found[1] then
    return vim.fs.dirname(found[1])
  end
end

--- Find the current buffer's NX project by searching upward for project.json.
---@param path? string starting directory
---@return string? name, table? targets, string? project_dir
local function find_project(path)
  path = path or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:h')
  local found = vim.fs.find('project.json', { path = path, upward = true })
  if not found[1] then return end

  local dir = vim.fs.dirname(found[1])
  local ok, text = pcall(vim.fn.readfile, found[1])
  if not ok then return end

  local ok2, data = pcall(vim.fn.json_decode, table.concat(text, '\n'))
  if not ok2 or type(data) ~= 'table' then return end

  local name = data.name or vim.fn.fnamemodify(dir, ':t')
  local targets = data.targets or {}
  return name, targets, dir
end

--- Get the nx binary command.
---@param root string workspace root
---@return string?
local function nx_cmd(root)
  local npx_nx = vim.fs.joinpath(root, 'node_modules', '.bin', 'nx')
  if vim.fn.executable(npx_nx) == 1 then return npx_nx end
  if vim.fn.executable('nx') == 1 then return 'nx' end
  if vim.fn.executable('npx') == 1 then return 'npx nx' end
end

--- Strip all ANSI/VT escape sequences from a string.
local function strip_ansi(s)
  s = s:gsub('\027%[[%d;:]*[A-Za-z]', '')  -- CSI sequences (colors, cursor, etc)
  s = s:gsub('\027%[[%d;:]*[mGKHJ]', '')    -- common SGR/erase
  s = s:gsub('\027%].-\007', '')             -- OSC sequences (BEL terminated)
  s = s:gsub('\027%].-\027\\', '')           -- OSC sequences (ST terminated)
  s = s:gsub('\027[%(%)][AB012]', '')        -- charset sequences
  s = s:gsub('\027[78DEHM]', '')             -- single-char escapes
  s = s:gsub('\r', '')                       -- carriage returns
  return s
end

--- Parse NX output to extract pass/fail summary.
---@param lines string[]
---@return boolean success, string summary
local function parse_result(lines)
  for i = #lines, math.max(1, #lines - 20), -1 do
    local line = strip_ansi(lines[i])
    if line:match('failed') and line:match('✖') then
      return false, vim.trim(line)
    end
    if line:match('succeeded') and line:match('✔') then
      return true, vim.trim(line)
    end
    if line:match('Successfully ran target') then
      return true, vim.trim(line)
    end
  end
  return false, 'finished'
end

--- Filter a raw output line into something useful for progress display.
--- Returns nil for blank/noise lines.
---@param line string
---@return string?
local function progress_line(line)
  local trimmed = vim.trim(line)
  if trimmed == '' then return nil end
  trimmed = strip_ansi(trimmed)
  trimmed = vim.trim(trimmed)
  -- Skip node deprecation warnings and empty decoration lines
  if trimmed:match('^%(node:') then return nil end
  if trimmed:match('^[─━═—]+$') then return nil end
  if trimmed:match('^>%s*NX') then return trimmed end
  if trimmed:match('^✖') or trimmed:match('^✔') then return trimmed end
  -- Keep lines that look like progress (targets, projects, results)
  if trimmed:match('^nx run') then return trimmed end
  if trimmed:match('succeeded') or trimmed:match('failed') then return trimmed end
  if trimmed:match('Running target') or trimmed:match('Building') then return trimmed end
  if trimmed:match('Successfully') then return trimmed end
  if trimmed:match('^%S') and #trimmed < 120 then return trimmed end
  return nil
end

--- Run a command in the background with live progress notifications.
---@param cmd string shell command
---@param label string display label for notifications
---@param cwd string working directory
local function run(cmd, label, cwd)
  last_output_lines = {}
  local progress_msg = 'Starting...'
  local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local spin_idx = 0
  local title = 'NX: ' .. label
  local notif_id = 'nx_run'

  -- Show initial notification
  Snacks.notify.info(progress_msg, { title = title, timeout = false, id = notif_id })

  -- Spinner + progress update timer
  local timer = vim.uv.new_timer()
  timer:start(100, 100, vim.schedule_wrap(function()
    spin_idx = (spin_idx + 1) % #spinner
    local icon = spinner[spin_idx + 1]
    Snacks.notify.info(icon .. ' ' .. progress_msg, { title = title, timeout = false, id = notif_id })
  end))

  local function collect(_, data)
    if not data then return end
    for _, line in ipairs(data) do
      if line ~= '' then
        table.insert(last_output_lines, line)
        local useful = progress_line(line)
        if useful then
          progress_msg = useful
        end
      end
    end
  end

  vim.fn.jobstart('FORCE_COLOR=1 ' .. cmd, {
    cwd = cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = collect,
    on_stderr = collect,
    on_exit = function(_, code)
      vim.schedule(function()
        timer:stop()
        timer:close()

        local success, summary = parse_result(last_output_lines)
        if code == 0 and success then
          Snacks.notify.info(summary, { title = title, timeout = 5000, id = notif_id })
        else
          Snacks.notify.error(summary .. '\n\n<leader>ol for details', { title = title, timeout = 10000, id = notif_id })
        end
      end)
    end,
  })
end

--- Open the last NX run output in a split with ANSI colors rendered.
function M.show_output()
  if #last_output_lines == 0 then
    vim.notify('No NX output available', vim.log.levels.INFO)
    return
  end
  vim.cmd('botright split')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].bufhidden = 'wipe'
  local chan = vim.api.nvim_open_term(buf, {})
  vim.schedule(function()
    for _, line in ipairs(last_output_lines) do
      vim.api.nvim_chan_send(chan, line .. '\r\n')
    end
    -- Scroll to top
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end)
end

--- Open a picker to select and run an NX target.
function M.pick()
  local root = find_workspace()
  if not root then
    vim.notify('Not in an NX workspace (nx.json not found)', vim.log.levels.WARN)
    return
  end

  local bin = nx_cmd(root)
  if not bin then
    vim.notify('nx not found (install nx or use npx)', vim.log.levels.ERROR)
    return
  end

  local items = {}
  local project_name, targets = find_project()

  -- Project-specific targets
  if project_name and targets then
    for target in pairs(targets) do
      local cmd = bin .. ' run ' .. project_name .. ':' .. target
      table.insert(items, {
        text = project_name .. ':' .. target,
        cmd = cmd,
        label = project_name .. ':' .. target,
        kind = 'project',
        target = target,
        preview = { text = cmd, ft = 'sh' },
      })
    end
    table.sort(items, function(a, b) return a.text < b.text end)
  end

  -- Workspace-wide run-many targets
  local common = { 'build', 'test', 'lint', 'format', 'serve' }
  for _, target in ipairs(common) do
    local cmd = bin .. ' run-many -t ' .. target
    table.insert(items, {
      text = 'run-many -t ' .. target,
      cmd = cmd,
      label = 'run-many ' .. target,
      kind = 'workspace',
      target = target,
      preview = { text = cmd, ft = 'sh' },
    })
  end

  local icons = {
    build = ' ',
    test = ' ',
    lint = '󱄽 ',
    format = ' ',
    serve = ' ',
  }

  Snacks.picker({
    title = 'NX' .. (project_name and (' — ' .. project_name) or ''),
    items = items,
    format = function(item)
      local icon = icons[item.target] or ' '
      local hl = item.kind == 'workspace' and 'DiagnosticHint' or 'DiagnosticOk'
      return {
        { icon, hl },
        { ' ' },
        { item.text },
      }
    end,
    preview = 'preview',
    confirm = function(picker, item)
      picker:close()
      run(item.cmd, item.label, root)
    end,
  })
end

--- Run a specific target for the current buffer's project.
---@param target string e.g. "build", "test"
function M.run(target)
  local root = find_workspace()
  if not root then
    vim.notify('Not in an NX workspace', vim.log.levels.WARN)
    return
  end
  local bin = nx_cmd(root)
  if not bin then
    vim.notify('nx not found', vim.log.levels.ERROR)
    return
  end

  local project_name = find_project()
  if not project_name then
    vim.notify('No project.json found for current buffer', vim.log.levels.WARN)
    return
  end

  local label = project_name .. ':' .. target
  run(bin .. ' run ' .. label, label, root)
end

--- Run-many a target across the workspace.
---@param target string e.g. "build", "test"
function M.run_many(target)
  local root = find_workspace()
  if not root then
    vim.notify('Not in an NX workspace', vim.log.levels.WARN)
    return
  end
  local bin = nx_cmd(root)
  if not bin then
    vim.notify('nx not found', vim.log.levels.ERROR)
    return
  end

  run(bin .. ' run-many -t ' .. target, 'run-many ' .. target, root)
end

return M
