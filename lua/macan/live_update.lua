local M = {}

-- Store active watchers and debounce timers
local active_watchers = {}
local debounce_timers = {}
local running_analysis = {} -- Track files currently being analyzed

-- Configuration
local config = {
  enabled = true,
  debounce_ms = 1000, -- Wait 1 second after last change before running analysis
  auto_run_on_save = true,
  auto_run_on_marker_change = true,
}

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})
end

function M.get_config()
  return config
end

function M.enable()
  config.enabled = true
  vim.notify('Live updates enabled', vim.log.levels.INFO)
end

function M.disable()
  config.enabled = false
  -- Clear all active timers
  for filepath, timer in pairs(debounce_timers) do
    if timer then
      timer:stop()
      timer:close()
    end
  end
  debounce_timers = {}
  vim.notify('Live updates disabled', vim.log.levels.INFO)
end

function M.toggle()
  if config.enabled then
    M.disable()
  else
    M.enable()
  end
end

local function is_c_file(filepath)
  if not filepath or filepath == '' then
    return false
  end
  local ext = vim.fn.fnamemodify(filepath, ':e')
  return ext == 'c' or ext == 'h' or ext == 'cpp' or ext == 'cc' or ext == 'cxx'
end

function M.is_analysis_running(filepath)
  return running_analysis[filepath] == true
end

function M.set_analysis_running(filepath, running)
  running_analysis[filepath] = running
end

local function run_analysis_for_file(filepath)
  if not config.enabled then
    return
  end
  
  if not is_c_file(filepath) then
    return
  end
  
  -- Check if analysis is already running for this file
  if running_analysis[filepath] then
    return
  end
  
  -- Check if we have markers set for this file
  local markers_mod = require('macan.markers')
  local markers = markers_mod.get_markers()
  if not markers.start or not markers.end_ then
    -- No markers set, don't run analysis
    return
  end
  
  -- Check if llvm-mca is available
  local mca = require('macan.llvm_mca')
  local config = require('macan.config').get()
  local mca_config = config.llvm_mca
  local compiler_config = config.compiler

  if not mca.is_available(mca_config.path) then
    return
  end

  if not mca.is_available(compiler_config.path) then
    return
  end
  
  -- Mark analysis as running
  running_analysis[filepath] = true
  
  vim.notify('Running live LLVM-MCA analysis...', vim.log.levels.INFO)
  
  -- Run the full analysis pipeline
  local output_mod = require('macan.output')
  local cc_mod = require('macan.compile_commands')
  local asmgen_mod = require('macan.asmgen')
  local flags_ui = require('macan.compile_flags_ui')
  
  local compile_cmd, err = cc_mod.get_compile_command_for_file(filepath)
  if not compile_cmd then
    vim.notify('Live update: Error getting compile command: ' .. (err or 'Unknown error'), vim.log.levels.WARN)
    running_analysis[filepath] = false
    return
  end
  
  local custom_flags = flags_ui.get_custom_flags(filepath)
  local use_cmd = custom_flags or compile_cmd
  
  local sfile, gen_err = asmgen_mod.generate_s_file(filepath, markers.start, markers.end_, use_cmd, compiler_config.path)
  if not sfile then
    vim.notify('Live update: Error generating .s file: ' .. (gen_err or 'Unknown error'), vim.log.levels.WARN)
    running_analysis[filepath] = false
    return
  end
  
  local output = mca.run_on_file(sfile)
  local parsed = mca.parse_output(output)
  
  -- Store raw output for MacanShowRawOutput command
  vim.g.macan_last_raw_output = output
  
  -- Perform dependency analysis
  local dependency_analysis = nil
  if output and parsed and parsed.timeline then
    local dep_mod = require('macan.dependency_analysis')
    dependency_analysis = dep_mod.analyze_dependencies(output)
  end
  
  output_mod.show_parsed_sections(parsed, dependency_analysis)
  
  vim.notify('Live LLVM-MCA analysis completed', vim.log.levels.INFO)
  
  -- Mark analysis as completed
  running_analysis[filepath] = false
end

local function debounced_analysis(filepath)
  -- Clear existing timer for this file
  if debounce_timers[filepath] then
    debounce_timers[filepath]:stop()
    debounce_timers[filepath]:close()
  end
  
  -- Create new timer
  debounce_timers[filepath] = vim.loop.new_timer()
  debounce_timers[filepath]:start(config.debounce_ms, 0, vim.schedule_wrap(function()
    run_analysis_for_file(filepath)
    -- Clean up timer
    if debounce_timers[filepath] then
      debounce_timers[filepath]:close()
      debounce_timers[filepath] = nil
    end
  end))
end

function M.setup_autocommands()
  -- Create augroup for live updates
  local augroup = vim.api.nvim_create_augroup('MacanLiveUpdate', { clear = true })
  
  if config.auto_run_on_save then
    -- Trigger on file save
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = augroup,
      pattern = '*.c,*.h,*.cpp,*.cc,*.cxx',
      callback = function(args)
        if config.enabled then
          debounced_analysis(args.file)
        end
      end,
    })
  end
  
  -- We could also add TextChanged events, but they might be too frequent
  -- Uncomment if you want live updates as you type (not recommended for performance)
  --[[
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = augroup,
    pattern = '*.c,*.h,*.cpp,*.cc,*.cxx',
    callback = function(args)
      if config.enabled then
        debounced_analysis(vim.api.nvim_buf_get_name(args.buf))
      end
    end,
  })
  --]]
end

function M.trigger_manual_update()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == '' then
    vim.notify('No file open for live update', vim.log.levels.ERROR)
    return
  end
  
  if not is_c_file(filepath) then
    vim.notify('Live updates only work with C/C++ files', vim.log.levels.ERROR)
    return
  end
  
  run_analysis_for_file(filepath)
end

function M.show_status()
  local status = config.enabled and 'enabled' or 'disabled'
  local debounce_info = string.format('debounce: %dms', config.debounce_ms)
  local save_info = config.auto_run_on_save and 'on-save: yes' or 'on-save: no'
  
  vim.notify(string.format('Live updates: %s (%s, %s)', status, debounce_info, save_info), vim.log.levels.INFO)
end

return M 