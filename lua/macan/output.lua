local M = {}

-- Keep track of analysis windows to close them when needed
local analysis_windows = {}

local function close_existing_analysis_windows()
  for _, win_id in ipairs(analysis_windows) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end
  analysis_windows = {}
end

function M.show_in_split(text)
  -- Close any existing analysis windows first
  close_existing_analysis_windows()
  
  -- Create a vertical split on the right side
  vim.cmd('rightbelow vsplit')
  local buf = vim.api.nvim_get_current_buf()
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_name(buf, 'LLVM-MCA Output')
  -- Set content
  local lines = {}
  for line in text:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- Set a reasonable width for the split
  vim.api.nvim_win_set_width(0, math.max(80, math.floor(vim.o.columns * 0.4)))
  
  -- Track this window
  table.insert(analysis_windows, vim.api.nvim_get_current_win())
end

function M.show_parsed_sections(parsed, dependency_analysis)
  -- Close any existing analysis windows first
  close_existing_analysis_windows()
  
  -- Save the current window to return focus to it later
  local original_win = vim.api.nvim_get_current_win()
  
  -- Create a vertical split on the right side
  vim.cmd('rightbelow vsplit')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_name(buf, 'LLVM-MCA Analysis')
  
  local lines = {}
  
  -- Add summary section
  table.insert(lines, '                               SUMMARY SECTION')
  table.insert(lines, '')
  
  -- Display structured summary metrics if available
  if parsed.summary_metrics then
    local metrics = parsed.summary_metrics
    
    table.insert(lines, string.format('%-20s %s', 'Iterations:', metrics.iterations or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'Instructions:', metrics.instructions or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'Total Cycles:', metrics.total_cycles or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'Total uOps:', metrics.total_uops or 'N/A'))
    table.insert(lines, '')
    table.insert(lines, string.format('%-20s %s', 'Dispatch Width:', metrics.dispatch_width or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'uOps Per Cycle:', metrics.uops_per_cycle or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'IPC:', metrics.ipc or 'N/A'))
    table.insert(lines, string.format('%-20s %s', 'Block RThroughput:', metrics.block_rthroughput or 'N/A'))
  elseif parsed.summary and #parsed.summary > 0 then
    -- Fallback to raw summary lines
    for _, line in ipairs(parsed.summary) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, '(No summary found in output)')
  end
  
  table.insert(lines, '')
  table.insert(lines, '')
  
  -- Add timeline section
  table.insert(lines, '                               TIMELINE SECTION')
  if dependency_analysis then
    local syntax = dependency_analysis.assembly_syntax or "unknown"
    table.insert(lines, string.format('                    (Dependencies Highlighted - %s syntax)', syntax:upper()))
  end
  table.insert(lines, '')
  
  local timeline_start_line = #lines + 1
  
  if parsed.timeline and #parsed.timeline > 0 then
    for _, line in ipairs(parsed.timeline) do
      table.insert(lines, line)
    end
  else
    table.insert(lines, '(No timeline found in output)')
    table.insert(lines, '')
    table.insert(lines, 'Debug info: Use :MacanShowRawOutput to see the full LLVM-MCA output')
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Apply dependency highlighting if analysis is provided
  if dependency_analysis then
    M.apply_dependency_highlighting(buf, timeline_start_line, dependency_analysis)
  end
  
  -- Set a reasonable width for the split
  vim.api.nvim_win_set_width(0, math.max(80, math.floor(vim.o.columns * 0.4)))
  
  -- Set cursor to the timeline section
  for i, line in ipairs(lines) do
    if line:match('TIMELINE SECTION') then
      vim.api.nvim_win_set_cursor(0, {i + 2, 0}) -- Position after the header
      break
    end
  end
  
  -- Track this window
  table.insert(analysis_windows, vim.api.nvim_get_current_win())
  
  -- Store buffer and dependency analysis for interactive features
  vim.g.macan_analysis_buffer = buf
  vim.g.macan_dependency_analysis = dependency_analysis
  vim.g.macan_timeline_start_line = timeline_start_line
  
  -- Set up cursor movement highlighting
  if dependency_analysis then
    M.setup_cursor_highlighting(buf)
  end
  
  -- Return focus to the original window with the source file
  vim.api.nvim_set_current_win(original_win)
end

function M.show_raw_output(raw_output)
  -- Close any existing analysis windows first
  close_existing_analysis_windows()
  
  -- Save the current window to return focus to it later
  local original_win = vim.api.nvim_get_current_win()
  
  -- Create a vertical split on the right side
  vim.cmd('rightbelow vsplit')
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_name(buf, 'LLVM-MCA Raw Output')
  
  local lines = {}
  table.insert(lines, '                            LLVM-MCA RAW OUTPUT')
  table.insert(lines, '')
  
  if raw_output then
    for line in raw_output:gmatch("([^\n]*)\n?") do
      table.insert(lines, line)
    end
  else
    table.insert(lines, '(No raw output available)')
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set a reasonable width for the split
  vim.api.nvim_win_set_width(0, math.max(80, math.floor(vim.o.columns * 0.4)))
  
  -- Track this window
  table.insert(analysis_windows, vim.api.nvim_get_current_win())
  
  -- Return focus to the original window
  vim.api.nvim_set_current_win(original_win)
end

-- Apply dependency highlighting to the timeline buffer
function M.apply_dependency_highlighting(buf, timeline_start_line, dependency_analysis)
  -- Define highlight groups for dependencies with more subtle colors
  vim.api.nvim_set_hl(0, 'MacanDependency', { fg = '#ff6b6b', bold = true })
  vim.api.nvim_set_hl(0, 'MacanDependent', { fg = '#4ecdc4', bold = true })
  vim.api.nvim_set_hl(0, 'MacanCurrentInstruction', { bg = '#3d3d3d', fg = '#ffffff' })
  vim.api.nvim_set_hl(0, 'MacanHasDependencies', { fg = '#ffa500', italic = true })  -- Orange for instructions with deps
  
  -- Create a mapping from instruction index to buffer line
  local instruction_to_line = {}
  local lines = vim.api.nvim_buf_get_lines(buf, timeline_start_line - 1, -1, false)
  
  for i, line in ipairs(lines) do
    local index_pattern = "%[(%d+),(%d+)%]"
    local iteration, instruction_idx = line:match(index_pattern)
    if instruction_idx then
      instruction_to_line[tonumber(instruction_idx)] = timeline_start_line + i - 1
    end
  end
  
  -- Don't highlight all dependencies at once - it's too overwhelming
  -- Instead, just mark instructions that have dependencies with a subtle highlight
  for _, dep_info in pairs(dependency_analysis.dependencies) do
    local line_num = instruction_to_line[dep_info.instruction.index]
    if line_num then
      -- Only highlight instructions that have dependencies (not all of them)
      if #dep_info.depends_on > 0 then
        -- Use a subtle highlight to indicate this instruction has dependencies
        vim.api.nvim_buf_add_highlight(buf, -1, 'MacanHasDependencies', line_num - 1, 0, 10)  -- Just highlight the index part
      end
    end
  end
  
  -- Add a note about interactive highlighting
  local note_lines = {
    "",
    "   Move cursor over instructions to see what they depend on",
    "   Red: Instructions this one depends on",
    "   Orange: Instructions that have dependencies",
    ""
  }
  
  -- Insert the note at the beginning of the timeline section
  vim.api.nvim_buf_set_lines(buf, timeline_start_line, timeline_start_line, false, note_lines)
  
  -- Update the timeline start line since we added lines
  vim.g.macan_timeline_start_line = timeline_start_line + #note_lines
end

-- Set up cursor movement highlighting for interactive dependency inspection
function M.setup_cursor_highlighting(buf)
  local ns_id = vim.api.nvim_create_namespace('macan_cursor_deps')
  
  -- Clear any existing autocmds for this buffer
  vim.api.nvim_create_augroup('MacanCursorHighlight', { clear = true })
  
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = 'MacanCursorHighlight',
    buffer = buf,
    callback = function()
      -- Clear previous highlights
      vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
      
      local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
      local line_content = vim.api.nvim_buf_get_lines(buf, cursor_line - 1, cursor_line, false)[1]
      
      if not line_content then return end
      
      -- Extract instruction index from current line
      local index_pattern = "%[(%d+),(%d+)%]"
      local iteration, instruction_idx = line_content:match(index_pattern)
      
      if not instruction_idx then return end
      
      local instr_idx = tonumber(instruction_idx)
      local dependency_analysis = vim.g.macan_dependency_analysis
      local timeline_start_line = vim.g.macan_timeline_start_line
      
      if not dependency_analysis or not timeline_start_line then return end
      
      -- Highlight current instruction
      vim.api.nvim_buf_add_highlight(buf, ns_id, 'MacanCurrentInstruction', cursor_line - 1, 0, -1)
      
      -- Find and highlight dependencies
      -- Find the dependency info by matching instruction index (not array index)
      local dep_info = nil
      for _, dep_entry in pairs(dependency_analysis.dependencies) do
        if dep_entry.instruction.index == instr_idx then
          dep_info = dep_entry
          break
        end
      end
      
      if dep_info then
        -- Create instruction index to line mapping (use updated timeline start line)
        local updated_timeline_start = vim.g.macan_timeline_start_line or timeline_start_line
        local instruction_to_line = {}
        local lines = vim.api.nvim_buf_get_lines(buf, updated_timeline_start - 1, -1, false)
        
        for i, line in ipairs(lines) do
          local iter, idx = line:match(index_pattern)
          if idx then
            instruction_to_line[tonumber(idx)] = updated_timeline_start + i - 1
          end
        end
        
        -- Highlight dependencies (instructions this one depends on)
        for _, dep_idx in ipairs(dep_info.depends_on) do
          -- Find the dependency instruction by array index
          local dep_instr = dependency_analysis.dependencies[dep_idx]
          if dep_instr then
            local dep_line = instruction_to_line[dep_instr.instruction.index]
            if dep_line then
              vim.api.nvim_buf_add_highlight(buf, ns_id, 'MacanDependency', dep_line - 1, 0, -1)
            end
          end
        end
        
        -- Show dependency info in status line with register details
        local dep_count = #dep_info.depends_on
        local dep_details = {}
        
        -- Get dependency analysis module to parse operands
        local dep_analysis = require('macan.dependency_analysis')
        local syntax = dependency_analysis.assembly_syntax or "att"
        
        for _, dep_idx in ipairs(dep_info.depends_on) do
          local dep_type = dep_info.dependency_types[dep_idx]
          local dep_register = dep_info.dependency_registers[dep_idx]
          local dep_instr = dependency_analysis.dependencies[dep_idx]
          
          if dep_instr then
            if dep_register then
              table.insert(dep_details, string.format("[%d]:%s on %%%s", dep_instr.instruction.index, dep_type or "RAW", dep_register))
            else
              table.insert(dep_details, string.format("[%d]:%s", dep_instr.instruction.index, dep_type or "RAW"))
            end
          end
        end
        
        local details_str = #dep_details > 0 and (" " .. table.concat(dep_details, ", ")) or ""
        local status_msg = string.format("Instr [%d]: %d dependencies%s [%s syntax]", 
          instr_idx, dep_count, details_str, syntax)
        vim.api.nvim_echo({{status_msg, 'Normal'}}, false, {})
      end
    end
  })
end

-- Expose function to close analysis windows
function M.close_analysis_windows()
  close_existing_analysis_windows()
end

return M 