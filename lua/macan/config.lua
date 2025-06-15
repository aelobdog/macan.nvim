local M = {}

-- Default configuration
local default_config = {
  llvm_mca = {
    path = "llvm-mca",  -- Path to llvm-mca executable
    march = nil,             -- No default architecture - let LLVM-MCA auto-detect
    extra_args = "-iterations=1 -timeline -timeline-max-iterations=1 -timeline-max-cycles=1000",
  },
  compiler = {
    path = "gcc", -- Default compiler
    asm_flag = "-S"
  },
  live_update = {
    enabled = true,
    debounce_ms = 1000
  },
  ui = {
    dependency_highlight = true,
    colors = {
      dependency = "DiffDelete",      -- Red highlighting for dependencies
      current_instruction = "CursorLine"  -- Gray highlighting for current instruction
    }
  }
}

-- Current configuration (starts as copy of default)
local current_config = vim.deepcopy(default_config)

-- Get the current configuration
function M.get()
  return current_config
end

-- Get a specific configuration value with dot notation (e.g., "llvm_mca.march")
function M.get_value(key)
  local keys = vim.split(key, ".", { plain = true })
  local value = current_config
  
  for _, k in ipairs(keys) do
    if type(value) == "table" and value[k] ~= nil then
      value = value[k]
    else
      return nil
    end
  end
  
  return value
end

-- Set a specific configuration value with dot notation
function M.set_value(key, value)
  local keys = vim.split(key, ".", { plain = true })
  local config = current_config
  
  -- Navigate to the parent table
  for i = 1, #keys - 1 do
    local k = keys[i]
    if type(config[k]) ~= "table" then
      config[k] = {}
    end
    config = config[k]
  end
  
  -- Set the final value
  config[keys[#keys]] = value
end

-- Update configuration with user-provided values
function M.setup(user_config)
  if user_config then
    current_config = vim.tbl_deep_extend("force", current_config, user_config)
  end
end

-- Get the llvm-mca command with all configured options
function M.get_llvm_mca_command(filepath, extra_args)
  local cmd_parts = { current_config.llvm_mca.path }
  
  -- Add -mcpu flag if configured
  if current_config.llvm_mca.march then
    table.insert(cmd_parts, "-mcpu=" .. current_config.llvm_mca.march)
  end
  
  -- Add extra arguments (either provided or default)
  local args = extra_args or current_config.llvm_mca.extra_args
  if args then
    table.insert(cmd_parts, args)
  end
  
  -- Add the filepath
  table.insert(cmd_parts, vim.fn.shellescape(filepath))
  
  -- Add error redirection
  table.insert(cmd_parts, "2>&1")
  
  return table.concat(cmd_parts, " ")
end

-- Get list of common CPU architectures for -mcpu
function M.get_common_march_values()
  return {
    -- Intel architectures
    "nehalem", "westmere", "sandybridge", "ivybridge", 
    "haswell", "broadwell", "skylake", "skylake-avx512",
    "cascadelake", "cooperlake", "icelake-client", "icelake-server",
    "tigerlake", "alderlake", "sapphirerapids",
    
    -- AMD architectures  
    "btver1", "btver2", "bdver1", "bdver2", "bdver3", "bdver4",
    "znver1", "znver2", "znver3", "znver4",
    
    -- Generic
    "x86-64", "x86-64-v2", "x86-64-v3", "x86-64-v4",
    
    -- ARM (if supported)
    "armv7-a", "armv8-a", "cortex-a53", "cortex-a57", "cortex-a72"
  }
end

-- Reset configuration to defaults
function M.reset()
  current_config = vim.deepcopy(default_config)
end

return M 