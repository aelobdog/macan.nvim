local M = {}

-- Flag to ensure commands are only defined once
local commands_defined = false

-- Define all commands (called by both setup and when plugin loads)
local function define_commands()
  if commands_defined then
    return
  end
  commands_defined = true

  vim.api.nvim_create_user_command('MacanHelp', function()
    local help_text = [[
Macan LLVM-MCA Plugin Commands:

Essential Core:
  :MacanRunMCA              - Run LLVM-MCA analysis manually
  :MacanSetStart            - Set analysis start point at current line
  :MacanSetEnd              - Set analysis end point at current line
  :MacanClearMarkers        - Clear start/end markers

Live Updates:
  :MacanLiveToggle          - Toggle live updates (shows current status)

Display:
  :MacanShowRawOutput       - Show raw LLVM-MCA output
  :MacanCloseAnalysis       - Close analysis window

Configuration:
  :MacanEditCompileFlags    - Edit compile flags for current file
  :MacanClearCustomFlags    - Clear custom compile flags
  :MacanSetMarch <arch>     - Set CPU architecture (e.g. skylake)
  :MacanConfig              - Show/manage configuration settings

Help:
  :MacanHelp                - Show this help message

For more info, see the documentation or README.
]]
    vim.notify(help_text, vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command('MacanConfig', function(opts)
    local config = require('macan.config')
    local live_update = require('macan.live_update')
    local cc = require('macan.compile_commands')
    local flags_ui = require('macan.compile_flags_ui')
    
    local subcommand = opts.args
    local filepath = vim.api.nvim_buf_get_name(0)
    
    if subcommand == 'status' or subcommand == '' then
      -- Show overall configuration status
      local march = config.get_value('llvm_mca.march')
      local extra_args = config.get_value('llvm_mca.extra_args')
      local live_config = live_update.get_config()
      local live_status = live_config.enabled and 'enabled' or 'disabled'
      
      local status_text = string.format([[
Macan Configuration Status:

CPU Architecture (-mcpu): %s
LLVM-MCA Extra Args: %s
Live Updates: %s (debounce: %dms)
Auto-run on save: %s

Use ':MacanConfig help' for available subcommands.
]], 
        march or 'default', 
        extra_args or 'default',
        live_status, 
        live_config.debounce_ms,
        live_config.auto_run_on_save and 'yes' or 'no'
      )
      
      if filepath ~= '' then
        local custom_flags = flags_ui.get_custom_flags(filepath)
        if custom_flags then
          status_text = status_text .. '\nCustom compile flags set for current file: ' .. custom_flags
        else
          status_text = status_text .. '\nNo custom compile flags for current file'
        end
      end
      
      vim.notify(status_text, vim.log.levels.INFO)
      
    elseif subcommand == 'march' then
      local march = config.get_value('llvm_mca.march')
      if march then
        vim.notify('Current -mcpu setting: ' .. march, vim.log.levels.INFO)
      else
        vim.notify('No -mcpu setting configured (using LLVM-MCA default)', vim.log.levels.INFO)
      end
      
    elseif subcommand == 'extra-args' then
      local extra_args = config.get_value('llvm_mca.extra_args')
      if extra_args then
        vim.notify('Current LLVM-MCA extra args: ' .. extra_args, vim.log.levels.INFO)
      else
        vim.notify('No extra args configured (using defaults)', vim.log.levels.INFO)
      end
      
    elseif subcommand == 'march-list' then
      local march_values = config.get_common_march_values()
      local message = 'Common -mcpu values:\n' .. table.concat(march_values, ', ')
      vim.notify(message, vim.log.levels.INFO)
      
    elseif subcommand == 'march-clear' then
      config.set_value('llvm_mca.march', nil)
      vim.notify('Cleared -mcpu setting (will use LLVM-MCA default)', vim.log.levels.INFO)
      
    elseif subcommand == 'flags' then
      if filepath == '' then
        vim.notify('No file open.', vim.log.levels.ERROR)
        return
      end
      local cmd, err = cc.get_compile_command_for_file(filepath)
      if cmd then
        local custom_flags = flags_ui.get_custom_flags(filepath)
        local display_cmd = custom_flags or cmd
        vim.notify('Current compile command:\n' .. display_cmd, vim.log.levels.INFO)
      else
        vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
      end
      
    elseif subcommand == 'help' then
      local help_text = [[
MacanConfig subcommands:

  :MacanConfig              - Show configuration status
  :MacanConfig status       - Same as above
  :MacanConfig march        - Show current CPU architecture
  :MacanConfig march-list   - List common CPU architectures
  :MacanConfig march-clear  - Clear CPU architecture setting
  :MacanConfig extra-args   - Show current LLVM-MCA extra arguments
  :MacanConfig flags        - Show current compile flags for file
  :MacanConfig help         - Show this help
]]
      vim.notify(help_text, vim.log.levels.INFO)
    else
      vim.notify('Unknown subcommand: ' .. subcommand .. '. Use :MacanConfig help', vim.log.levels.ERROR)
    end
  end, { 
    nargs = '?',
    complete = function()
      return {'status', 'march', 'march-list', 'march-clear', 'extra-args', 'flags', 'help'}
    end
  })

  vim.api.nvim_create_user_command('MacanSetStart', function()
    require('macan.markers').set_start()
  end, {})

  vim.api.nvim_create_user_command('MacanSetEnd', function()
    require('macan.markers').set_end()
  end, {})

  vim.api.nvim_create_user_command('MacanClearMarkers', function()
    require('macan.markers').clear_markers()
    -- Also close any existing analysis windows to prevent conflicts
    local output_mod = require('macan.output')
    if output_mod.close_analysis_windows then
      output_mod.close_analysis_windows()
    end
  end, {})

  -- Live update command
  vim.api.nvim_create_user_command('MacanLiveToggle', function()
    local live_update = require('macan.live_update')
    live_update.toggle()
    -- Show status after toggling
    local config = live_update.get_config()
    local status = config.enabled and 'enabled' or 'disabled'
    local debounce_info = string.format('debounce: %dms', config.debounce_ms)
    local save_info = config.auto_run_on_save and 'on-save: yes' or 'on-save: no'
    vim.notify(string.format('Live updates: %s (%s, %s)', status, debounce_info, save_info), vim.log.levels.INFO)
  end, {})

  vim.api.nvim_create_user_command('MacanRunMCA', function()
    local mca = require('macan.llvm_mca')
    local output_mod = require('macan.output')
    local markers_mod = require('macan.markers')
    local cc_mod = require('macan.compile_commands')
    local asmgen_mod = require('macan.asmgen')
    local flags_ui = require('macan.compile_flags_ui')
    local live_update = require('macan.live_update')
    
    if not mca.is_available() then
      vim.notify('llvm-mca is NOT available in PATH.', vim.log.levels.ERROR)
      return
    end
    
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' then
      vim.notify('No file to run llvm-mca on.', vim.log.levels.ERROR)
      return
    end
    
    -- Check if live update is already running analysis for this file
    if live_update.is_analysis_running(filepath) then
      vim.notify('Analysis already running for this file, please wait...', vim.log.levels.WARN)
      return
    end
    
    -- Mark that we're running analysis to prevent live updates from duplicating
    live_update.set_analysis_running(filepath, true)
    
    local markers = markers_mod.get_markers()
    if not markers.start or not markers.end_ then
      vim.notify('Please set both LLVM_MCA_START and LLVM_MCA_END markers.', vim.log.levels.ERROR)
      live_update.set_analysis_running(filepath, false)
      return
    end
    
    local compile_cmd, err = cc_mod.get_compile_command_for_file(filepath)
    if not compile_cmd then
      vim.notify('Error getting compile command: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
      live_update.set_analysis_running(filepath, false)
      return
    end
    
    local custom_flags = flags_ui.get_custom_flags(filepath)
    local use_cmd = custom_flags or compile_cmd
    
    local sfile, gen_err = asmgen_mod.generate_s_file(filepath, markers.start, markers.end_, use_cmd)
    
    if sfile then
      -- Check if the file actually exists
      local stat = vim.loop.fs_stat(sfile)
      if not stat then
        vim.notify('Generated .s file does not exist on disk!', vim.log.levels.ERROR)
        live_update.set_analysis_running(filepath, false)
        return
      end
    else
      vim.notify('Error generating .s file: ' .. (gen_err or 'Unknown error'), vim.log.levels.ERROR)
      live_update.set_analysis_running(filepath, false)
      return
    end
    
    local output = mca.run_on_file(sfile)
    local parsed = mca.parse_output(output)
    
    -- Analyze dependencies automatically
    local dep_analysis = require('macan.dependency_analysis')
    local dependency_analysis = dep_analysis.analyze_dependencies(output)
    
    -- Show parsed sections with dependency highlighting
    output_mod.show_parsed_sections(parsed, dependency_analysis)
    
    -- Store the raw output and analysis for debugging if needed
    vim.g.macan_last_raw_output = output
    vim.g.macan_dependency_analysis = dependency_analysis
    
    -- Mark analysis as completed
    live_update.set_analysis_running(filepath, false)
  end, {})

  vim.api.nvim_create_user_command('MacanShowRawOutput', function()
    local output_mod = require('macan.output')
    if vim.g.macan_last_raw_output then
      output_mod.show_raw_output(vim.g.macan_last_raw_output)
    else
      vim.notify('No raw LLVM-MCA output available. Run MacanRunMCA first.', vim.log.levels.ERROR)
    end
  end, {})

  vim.api.nvim_create_user_command('MacanEditCompileFlags', function()
    local cc = require('macan.compile_commands')
    local flags_ui = require('macan.compile_flags_ui')
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' then
      vim.notify('No file open.', vim.log.levels.ERROR)
      return
    end
    local cmd, err = cc.get_compile_command_for_file(filepath)
    if not cmd then
      vim.notify('Error: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
      return
    end
    flags_ui.edit_flags_for_file(filepath, cmd)
  end, {})

  vim.api.nvim_create_user_command('MacanClearCustomFlags', function()
    local flags_ui = require('macan.compile_flags_ui')
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' then
      vim.notify('No file open.', vim.log.levels.ERROR)
      return
    end
    flags_ui.clear_custom_flags(filepath)
  end, {})

  -- Configuration commands for -mcpu flag
  vim.api.nvim_create_user_command('MacanSetMarch', function(opts)
    local config = require('macan.config')
    local march = opts.args
    if march == '' then
      vim.notify('Usage: :MacanSetMarch <architecture>', vim.log.levels.ERROR)
      vim.notify('Example: :MacanSetMarch skylake', vim.log.levels.INFO)
      return
    end
    config.set_value('llvm_mca.march', march)
    vim.notify('Set -mcpu=' .. march .. ' for LLVM-MCA analysis', vim.log.levels.INFO)
  end, { 
    nargs = 1,
    complete = function()
      local config = require('macan.config')
      return config.get_common_march_values()
    end
  })






  
  vim.api.nvim_create_user_command('MacanCloseAnalysis', function()
    local output_mod = require('macan.output')
    if output_mod.close_analysis_windows then
      output_mod.close_analysis_windows()
      vim.notify('Closed analysis windows', vim.log.levels.INFO)
    end
  end, {})



  -- Register cleanup on Neovim exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      require('macan.asmgen').cleanup_all()
      print("[macan] Cleaned up temporary files")
    end,
  })
end

-- Setup function for configuration (can be called to override defaults)
function M.setup(user_config)
  if user_config then
    -- Re-initialize with user configuration
    local config = require('macan.config')
    config.setup(user_config)
    
    -- Re-setup live updates with user config
    local live_update = require('macan.live_update')
    if user_config.live_update then
      live_update.setup(user_config.live_update)
      -- Re-setup autocommands with new config
      live_update.setup_autocommands()
    end
    
    print("[macan] Plugin reconfigured with user settings!")
  else
    print("[macan] Plugin already initialized with defaults. No changes made.")
  end
end

-- Auto-initialize when module is required (for package managers that don't call setup)
local function auto_initialize()
  -- Initialize configuration with defaults
  local config = require('macan.config')
  config.setup() -- Setup with default config
  
  -- Setup live updates with defaults
  local live_update = require('macan.live_update')
  live_update.setup() -- Setup with default config
  live_update.setup_autocommands()
  
  -- Define commands
  define_commands()
  
  -- Seed random number generator for temp file names
  math.randomseed(os.time())
end

-- Auto-initialize when module is required
auto_initialize()

return M 