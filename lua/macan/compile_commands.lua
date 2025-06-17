local M = {}

local function find_compile_commands_json(filepath)
  local root_dir = vim.fs.root(filepath, vim.g.root_spec or {'.git'})
  local build_dir = root_dir .. '/build' -- TODO: make this configurable

  -- TODO: do a recursive downward search for ccjson?
  --       or take the relative path (wrt. root_dir) to the ccjson from the user?

  local candidate = root_dir .. '/compile_commands.json'
  local stat = vim.loop.fs_stat(candidate)
  if stat and stat.type == 'file' then
    return candidate
  end

  candidate = build_dir .. '/compile_commands.json'
  stat = vim.loop.fs_stat(candidate)
  if stat and stat.type == 'file' then
    return candidate
  end

  return nil
end

local function read_json_file(path)
  local fd = io.open(path, 'r')
  if not fd then return nil end
  local content = fd:read('*a')
  fd:close()
  local ok, data = pcall(vim.fn.json_decode, content)
  if ok then return data end
  return nil
end

function M.get_compile_command_for_file(filepath)
  local abs_path = vim.fn.fnamemodify(filepath, ':p')
  local ccjson = find_compile_commands_json(vim.fn.getcwd())
  if not ccjson then return nil, 'No compile_commands.json found' end
  local data = read_json_file(ccjson)
  if not data then return nil, 'Failed to parse compile_commands.json' end
  for _, entry in ipairs(data) do
    if vim.fn.fnamemodify(entry.file, ':p') == abs_path then
      -- entry.command may be a string or entry.arguments may be an array
      if entry.command then
        return entry.command, nil
      elseif entry.arguments then
        return table.concat(entry.arguments, ' '), nil
      end
    end
  end
  return nil, 'No compile command found for file: ' .. filepath
end

return M 