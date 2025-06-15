local M = {}
local uv = vim.loop

-- Keep track of created temp files for cleanup
local temp_files = {}

-- Log file path
local log_file = vim.fn.expand('~/.cache/macan/debug.log')

-- Helper function to log messages silently
local function log_debug(message)
  local log_dir = vim.fn.expand('~/.cache/macan')
  vim.fn.mkdir(log_dir, 'p')
  
  local fd = io.open(log_file, 'a')
  if fd then
    fd:write(os.date('[%Y-%m-%d %H:%M:%S] ') .. message .. '\n')
    fd:close()
  end
end

local function insert_markers_and_write(src_lines, start_line, end_line)
  local out_lines = {}
  for i, line in ipairs(src_lines) do
    -- Insert LLVM_MCA_START before the start line
    if start_line and i == start_line then
      table.insert(out_lines, '__asm volatile("# LLVM-MCA-BEGIN foo":::"memory");')
      log_debug("Inserted LLVM_MCA_START before line " .. i .. ": " .. line)
    end
    
    table.insert(out_lines, line)
    
    -- Insert LLVM_MCA_END after the end line
    if end_line and i == end_line then
      table.insert(out_lines, '__asm volatile("# LLVM-MCA-END":::"memory");')
      log_debug("Inserted LLVM_MCA_END after line " .. i .. ": " .. line)
    end
  end
  
  log_debug("Total output lines: " .. #out_lines)
  log_debug("Start line: " .. tostring(start_line) .. ", End line: " .. tostring(end_line))
  
  return out_lines
end

-- Generate a unique but consistent hash for a file path
local function hash_path(path)
  local h = 0
  for i = 1, #path do
    h = (h * 31 + string.byte(path, i)) % 1000000
  end
  return string.format("%06d", h)
end

local function parse_ccjson_command(cmd)
  local args = {}
  local i, len = 1, #cmd
  while i <= len do
    while i <= len and cmd:sub(i, i):match("%s") do i = i + 1 end -- skip whitespace
    if i > len then break end

    local arg = ""
    local in_quote = false

    while i <= len do
      local c = cmd:sub(i, i)
      if c == '"' then
        arg = arg .. c
        i = i + 1
        while i <= len do
          local ch = cmd:sub(i, i)
          arg = arg .. ch
          i = i + 1
          if ch == '"' and cmd:sub(i - 2, i - 2) ~= '\\' then
            break
          end
        end
      elseif c:match("%s") and not in_quote then
        break
      else
        arg = arg .. c
        i = i + 1
      end
    end

    if #arg > 0 then
      table.insert(args, arg)
    end
  end
  return args
end

local function clean_compile_command(cmd)
  local args = parse_ccjson_command(cmd)

  -- Remove first arg (compiler path)
  table.remove(args, 1)

  local filtered = {}

  for i, arg in ipairs(args) do
    -- Stop if we hit '--' and ignore everything after
    if arg == '--' then
      break
    end

    local lower = arg:lower()
    if not (
      lower:match('^-dccompiler=') or
      lower:match('^-dcxxcompiler=') or
      lower:match('^/fo')
    ) then
      table.insert(filtered, arg)
    end
  end

  return filtered
end

function M.generate_s_file(cfile, start_line, end_line, compile_cmd, compiler)
  -- Read source lines
  local fd = io.open(cfile, 'r')
  if not fd then return nil, 'Failed to open source file' end
  local src = fd:read('*a')
  fd:close()
  local src_lines = {}
  for line in src:gmatch('([^\n]*)\n?') do
    table.insert(src_lines, line)
  end
  -- Insert markers (convert from 0-based to 1-based for Lua)
  local out_lines = insert_markers_and_write(src_lines, start_line and (start_line + 1), end_line and (end_line + 1))
  
  -- Create temp directory if it doesn't exist
  local tmp_dir = vim.fn.expand('~/.cache/macan')
  vim.fn.mkdir(tmp_dir, 'p')
  
  -- Generate filename based on input file path (hash)
  local file_hash = hash_path(cfile)
  local base_name = vim.fn.fnamemodify(cfile, ':t:r') -- Get base name without extension
  local tmp_c_path = string.format('%s/%s_%s.c', tmp_dir, base_name, file_hash)
  
  -- Log debug info
  log_debug("Creating temp C file at: " .. tmp_c_path)
  
  -- Write to temp file
  local out_fd = io.open(tmp_c_path, 'w')
  if not out_fd then return nil, 'Failed to open temp file for writing: ' .. tmp_c_path end
  out_fd:write(table.concat(out_lines, '\n'))
  out_fd:close()
  
  -- Prepare .s file path
  local tmp_s_path = tmp_c_path:gsub('%.c$', '.s')
  
  -- Keep track of created files for cleanup
  temp_files[cfile] = {c = tmp_c_path, s = tmp_s_path}
  
  -- flags extracted from the compile_commands.json entry
  local flags = clean_compile_command(compile_cmd)

  -- Build a simplified compile command with includes and defines
  local asm_flag = ""
  local compiler_no_ext = compiler:gsub("%.exe$", "")

  if compiler_no_ext == "gcc" or compiler_no_ext == "clang" then
    asm_flag = "-S -o " .. tmp_s_path
  elseif compiler_no_ext == "clang-cl" or compiler_no_ext == "cl" then
    asm_flag = "/c /Fa" .. tmp_s_path
  else
    vim.notify("Unrecognized compiler.")
    return
  end

  local cmd = compiler .. " " .. asm_flag
  
  -- Add all flags from the compile_commands.json entry 
  for _, flag in ipairs(flags) do
    cmd = cmd .. " " .. flag
  end
  
  -- Add input and output files
  cmd = cmd .. " " .. tmp_c_path
  
  -- Log debug info
  log_debug("Original compile command: " .. compile_cmd)
  log_debug("Simplified compile command: " .. cmd)
  
  -- Run compile command and capture exit code properly
  local exit_code
  if _VERSION == "Lua 5.1" then
    -- Lua 5.1 (exit code in return value)
    exit_code = os.execute(cmd)
  else
    -- Lua 5.2+ (returns true/false, exit_code)
    local success, _, code = os.execute(cmd)
    exit_code = success and 0 or code
  end
  
  -- Log debug info
  log_debug("Compile command exit code: " .. tostring(exit_code))
  
  if exit_code ~= 0 then
    return nil, 'Failed to generate .s file. Command: ' .. cmd .. ' (Exit code: ' .. tostring(exit_code) .. ')'
  end
  
  -- Check if file was actually created
  local stat = vim.loop.fs_stat(tmp_s_path)
  if not stat then
    return nil, 'Compile command returned success, but .s file was not created: ' .. tmp_s_path
  end
  
  log_debug("Successfully generated .s file at: " .. tmp_s_path)
  
  return tmp_s_path, nil
end

-- Clean up temp files for a specific input file
function M.cleanup_file(cfile)
  if temp_files[cfile] then
    os.remove(temp_files[cfile].c)
    os.remove(temp_files[cfile].s)
    temp_files[cfile] = nil
  end
end

-- Clean up all temp files
function M.cleanup_all()
  for cfile, files in pairs(temp_files) do
    os.remove(files.c)
    os.remove(files.s)
  end
  temp_files = {}
end

-- Get the path to the generated .s file for a given input file
function M.get_s_file_path(cfile)
  if temp_files[cfile] then
    return temp_files[cfile].s
  end
  return nil
end

return M