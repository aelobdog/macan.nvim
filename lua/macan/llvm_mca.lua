local M = {}

-- Helper function to trim whitespace
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Check if llvm-mca is available in PATH
function M.is_available()
  local handle = io.popen("which llvm-mca 2>/dev/null")
  if not handle then return false end
  local result = handle:read("*a")
  handle:close()
  return result ~= nil and result ~= ''
end

-- Run llvm-mca on a file and return output
function M.run_on_file(filepath, extra_args)
  local config = require('macan.config')
  local cmd = config.get_llvm_mca_command(filepath, extra_args)
  local handle = io.popen(cmd)
  if not handle then return nil, 'Failed to run llvm-mca' end
  local output = handle:read("*a")
  handle:close()
  return output
end

-- Parse llvm-mca output to extract instructions and timeline sections
function M.parse_output(output)
  local summary = {}
  local timeline = {}
  local in_summary = false
  local in_timeline = false
  local timeline_line_count = 0
  
  -- Extract specific summary metrics
  local summary_metrics = {}
  
  -- Store raw output for debugging
  local parsed = {
    summary = summary,
    timeline = timeline,
    raw_output = output,
    summary_metrics = summary_metrics
  }
  
  local lines = {}
  for line in output:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end
  
  for i, line in ipairs(lines) do
    -- Extract specific summary metrics
    local iterations = line:match("Iterations:%s*(%d+)")
    local instructions = line:match("Instructions:%s*(%d+)")
    local total_cycles = line:match("Total Cycles:%s*(%d+)")
    local total_uops = line:match("Total uOps:%s*(%d+)")
    local dispatch_width = line:match("Dispatch Width:%s*([%d%.]+)")
    local uops_per_cycle = line:match("uOps Per Cycle:%s*([%d%.]+)")
    local ipc = line:match("IPC:%s*([%d%.]+)")
    local block_rthroughput = line:match("Block RThroughput:%s*([%d%.]+)")
    
    if iterations then
      summary_metrics.iterations = iterations
    elseif instructions then
      summary_metrics.instructions = instructions
    elseif total_cycles then
      summary_metrics.total_cycles = total_cycles
    elseif total_uops then
      summary_metrics.total_uops = total_uops
    elseif dispatch_width then
      summary_metrics.dispatch_width = dispatch_width
    elseif uops_per_cycle then
      summary_metrics.uops_per_cycle = uops_per_cycle
    elseif ipc then
      summary_metrics.ipc = ipc
    elseif block_rthroughput then
      summary_metrics.block_rthroughput = block_rthroughput
    end
    
    -- Look for summary statistics section (starts after "Instructions:" count)
    if line:match("Instructions:%s*%d+") then
      in_summary = true
      in_timeline = false
      table.insert(summary, line)
    elseif in_summary and (line:match("Total Cycles:") or line:match("Total uOps:") or 
                          line:match("Dispatch Width:") or line:match("uOps Per Cycle:") or
                          line:match("IPC:") or line:match("Block RThroughput:") or
                          line:match("Iterations:")) then
      table.insert(summary, line)
    elseif line:match("Timeline view:") then
      in_summary = false
      in_timeline = true
      timeline_line_count = 0
      table.insert(timeline, line)
    elseif in_timeline then
      timeline_line_count = timeline_line_count + 1
      
      -- Stop timeline if we hit specific sections or patterns
      if line:match("Average [Ww]ait times") or line:match("^Average Wait Time") or
         line:match("^Resources:") or line:match("^Resource pressure") or 
         line:match("^Summary:") or line:match("^Register File") or
         line:match("^Dispatch Logic") or line:match("^Schedulers") or
         line:match("^Instruction Info") then
        in_timeline = false
      -- Also stop if we see an empty line followed by a capitalized section
      elseif trim(line) == "" and lines[i+1] and 
             (lines[i+1]:match("^[A-Z]") or lines[i+1]:match("Average")) then
        in_timeline = false
      else
        table.insert(timeline, line)
      end
    elseif in_summary and trim(line) == "" then
       -- Empty line might end summary section
       in_summary = false
    end
  end
  
  return parsed
end

return M 