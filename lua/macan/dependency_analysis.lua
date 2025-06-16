local M = {}

-- Helper function to trim whitespace
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

-- Parse a timeline line to extract instruction information
local function parse_timeline_line(line)
  -- Timeline format: [index] timeline_pattern instruction
  -- Example: [0,1]     D=====eeeeeeeeER    .    .    .    .  .   movss	(%rax), %xmm0
  local index_pattern = "%[(%d+),(%d+)%]"
  local iteration, instruction_idx = line:match(index_pattern)
  
  if not iteration or not instruction_idx then
    return nil
  end
  
  -- Find the instruction at the end - it starts with a letter and contains assembly syntax
  -- Look for pattern: mnemonic followed by operands (with tabs/spaces)
  local instruction = line:match("([a-z][a-z0-9]*[qwlbsd]?%s+[^%s].*)$")
  
  if not instruction then
    return nil
  end
  
  -- Extract timeline pattern (between ] and instruction)
  local bracket_end = line:find("%]")
  local instr_start = line:find(instruction, 1, true)
  local timeline_pattern = ""
  
  if bracket_end and instr_start then
    timeline_pattern = line:sub(bracket_end + 1, instr_start - 1)
  end
  
  return {
    iteration = tonumber(iteration),
    index = tonumber(instruction_idx),
    timeline = timeline_pattern,
    instruction = trim(instruction),
    raw_line = line
  }
end

-- Analyze timeline pattern to extract timing information
local function analyze_timeline_pattern(timeline)
  local dispatch_cycle = nil
  local execution_start = nil
  local execution_end = nil
  local retire_cycle = nil
  local stall_cycles = {}
  
  for i = 1, #timeline do
    local char = timeline:sub(i, i)
    if char == 'D' then
      dispatch_cycle = i - 1 -- 0-indexed
    elseif char == 'e' and not execution_start then
      execution_start = i - 1
    elseif char == 'E' then
      execution_end = i - 1
    elseif char == 'R' then
      retire_cycle = i - 1
    elseif char == '=' then
      table.insert(stall_cycles, i - 1)
    end
  end
  
  return {
    dispatch_cycle = dispatch_cycle,
    execution_start = execution_start,
    execution_end = execution_end,
    retire_cycle = retire_cycle,
    stall_cycles = stall_cycles,
    total_cycles = #timeline
  }
end

--[[
DEPENDENCY DETECTION LOGIC DOCUMENTATION:

This module detects instruction dependencies by analyzing:
1. Assembly syntax (AT&T vs Intel) to correctly parse operands
2. Register usage patterns (read-after-write dependencies)
3. Memory dependencies (same memory locations)
4. Timeline overlap (instructions that stall waiting for others)

ASSEMBLY SYNTAX DETECTION:
- AT&T syntax: registers prefixed with %, source-destination order (movq %rax, %rbx)
- Intel syntax: no % prefix, destination-source order (mov rbx, rax)

DEPENDENCY TYPES DETECTED:
1. RAW (Read-After-Write): Current instruction reads a register/memory that previous instruction writes

HEURISTICS USED:
- Timeline stalls indicate potential dependencies
- Register aliasing (rax/eax/ax/al are the same register)
- Memory address analysis for load/store dependencies
- Instruction ordering and execution overlap analysis
--]]

-- Detect assembly syntax from instruction text
local function detect_assembly_syntax(instructions)
  local att_indicators = 0
  local intel_indicators = 0
  
  for _, instr in ipairs(instructions) do
    local text = instr.instruction
    -- AT&T syntax indicators
    if text:match("%%[a-z]") then att_indicators = att_indicators + 1 end
    if text:match("%$[0-9]") then att_indicators = att_indicators + 1 end
    if text:match("[a-z]+[qwlb]%s") then att_indicators = att_indicators + 1 end
    
    -- Intel syntax indicators (less reliable, but absence of AT&T indicators)
    if not text:match("%%") and text:match("[a-z]+%s+[a-z]") then
      intel_indicators = intel_indicators + 1
    end
  end
  
  return att_indicators > intel_indicators and "att" or "intel"
end

-- Comprehensive register alias mapping for x86-64
local function get_register_aliases()
  return {
    -- 64-bit registers and their aliases
    rax = { "rax", "eax", "ax", "al", "ah" },
    rbx = { "rbx", "ebx", "bx", "bl", "bh" },
    rcx = { "rcx", "ecx", "cx", "cl", "ch" },
    rdx = { "rdx", "edx", "dx", "dl", "dh" },
    rsi = { "rsi", "esi", "si", "sil" },
    rdi = { "rdi", "edi", "di", "dil" },
    rbp = { "rbp", "ebp", "bp", "bpl" },
    rsp = { "rsp", "esp", "sp", "spl" },
    r8 = { "r8", "r8d", "r8w", "r8b" },
    r9 = { "r9", "r9d", "r9w", "r9b" },
    r10 = { "r10", "r10d", "r10w", "r10b" },
    r11 = { "r11", "r11d", "r11w", "r11b" },
    r12 = { "r12", "r12d", "r12w", "r12b" },
    r13 = { "r13", "r13d", "r13w", "r13b" },
    r14 = { "r14", "r14d", "r14w", "r14b" },
    r15 = { "r15", "r15d", "r15w", "r15b" },
    -- XMM registers
    xmm0 = { "xmm0" },
    xmm1 = { "xmm1" },
    xmm2 = { "xmm2" },
    xmm3 = { "xmm3" },
    xmm4 = { "xmm4" },
    xmm5 = { "xmm5" },
    xmm6 = { "xmm6" },
    xmm7 = { "xmm7" },
    xmm8 = { "xmm8" },
    xmm9 = { "xmm9" },
    xmm10 = { "xmm10" },
    xmm11 = { "xmm11" },
    xmm12 = { "xmm12" },
    xmm13 = { "xmm13" },
    xmm14 = { "xmm14" },
    xmm15 = { "xmm15" },
    -- YMM registers
    ymm0 = { "ymm0", "xmm0" },
    ymm1 = { "ymm1", "xmm1" },
    ymm2 = { "ymm2", "xmm2" },
    ymm3 = { "ymm3", "xmm3" },
    ymm4 = { "ymm4", "xmm4" },
    ymm5 = { "ymm5", "xmm5" },
    ymm6 = { "ymm6", "xmm6" },
    ymm7 = { "ymm7", "xmm7" },
    ymm8 = { "ymm8", "xmm8" },
    ymm9 = { "ymm9", "xmm9" },
    ymm10 = { "ymm10", "xmm10" },
    ymm11 = { "ymm11", "xmm11" },
    ymm12 = { "ymm12", "xmm12" },
    ymm13 = { "ymm13", "xmm13" },
    ymm14 = { "ymm14", "xmm14" },
    ymm15 = { "ymm15", "xmm15" },
    -- ZMM registers
    zmm0 = { "zmm0", "ymm0", "xmm0" },
    zmm1 = { "zmm1", "ymm1", "xmm1" },
    zmm2 = { "zmm2", "ymm2", "xmm2" },
    zmm3 = { "zmm3", "ymm3", "xmm3" },
    zmm4 = { "zmm4", "ymm4", "xmm4" },
    zmm5 = { "zmm5", "ymm5", "xmm5" },
    zmm6 = { "zmm6", "ymm6", "xmm6" },
    zmm7 = { "zmm7", "ymm7", "xmm7" },
    zmm8 = { "zmm8", "ymm8", "xmm8" },
    zmm9 = { "zmm9", "ymm9", "xmm9" },
    zmm10 = { "zmm10", "ymm10", "xmm10" },
    zmm11 = { "zmm11", "ymm11", "xmm11" },
    zmm12 = { "zmm12", "ymm12", "xmm12" },
    zmm13 = { "zmm13", "ymm13", "xmm13" },
    zmm14 = { "zmm14", "ymm14", "xmm14" },
    zmm15 = { "zmm15", "ymm15", "xmm15" },
    zmm16 = { "zmm16", "ymm16", "xmm16" },
    zmm17 = { "zmm17", "ymm17", "xmm17" },
    zmm18 = { "zmm18", "ymm18", "xmm18" },
    zmm19 = { "zmm19", "ymm19", "xmm19" },
    zmm20 = { "zmm20", "ymm20", "xmm20" },
    zmm21 = { "zmm21", "ymm21", "xmm21" },
    zmm22 = { "zmm22", "ymm22", "xmm22" },
    zmm23 = { "zmm23", "ymm23", "xmm23" },
    zmm24 = { "zmm24", "ymm24", "xmm24" },
    zmm25 = { "zmm25", "ymm25", "xmm25" },
    zmm26 = { "zmm26", "ymm26", "xmm26" },
    zmm27 = { "zmm27", "ymm27", "xmm27" },
    zmm28 = { "zmm28", "ymm28", "xmm28" },
    zmm29 = { "zmm29", "ymm29", "xmm29" },
    zmm30 = { "zmm30", "ymm30", "xmm30" },
    zmm31 = { "zmm31", "ymm31", "xmm31" }
  }
end

-- Check if two registers are aliases of each other
local function are_aliased_registers(reg1, reg2)
  local aliases = get_register_aliases()

  -- Normalize register names (remove % prefix if present)
  reg1 = reg1:gsub("^%%", "")
  reg2 = reg2:gsub("^%%", "")

  for base, alias_list in pairs(aliases) do
    local reg1_matches = false
    local reg2_matches = false

    for _, alias in ipairs(alias_list) do
      if reg1 == alias then reg1_matches = true end
      if reg2 == alias then reg2_matches = true end
    end

    if reg1_matches and reg2_matches then
      return true
    end
  end

  return false
end

-- Extract ALL registers from operand (handles complex memory addressing)
-- Returns: list of registers, is_memory_access, full_memory_expression
local function extract_registers_from_operand(operand)
  operand = trim(operand)
  local registers = {}

  -- Direct register reference
  local reg = operand:match("^%%?([a-z]+[0-9]*[a-z]*)$")
  if reg then 
    return {reg}, false, nil 
  end

  -- Memory operand - extract ALL registers from complex addressing
  -- AT&T: offset(%base,%index,scale) or (%base) or (, %index, scale)
  if operand:match("%(") then
    local mem_content = operand:match("%(([^%)]+)%)")
    if mem_content then
      -- Split by comma and extract all register-like parts
      for part in mem_content:gmatch("[^,]+") do
        part = trim(part)
        -- Skip empty parts, pure numbers (offsets/scales), and immediate values
        if part ~= "" and not part:match("^[0-9]+$") and not part:match("^%$") then
          -- Extract register name (with or without % prefix)
          local register = part:match("^%%?([a-z]+[0-9]*[a-z]*)$")
          if register then
            table.insert(registers, register)
          end
        end
      end
    end
    return registers, true, operand
  end

  -- Intel syntax memory: [base+index*scale+offset]
  if operand:match("%[") then
    local mem_content = operand:match("%[([^%]]+)%]")
    if mem_content then
      -- Extract registers from Intel syntax (more complex parsing needed)
      for register in mem_content:gmatch("([a-z]+[0-9]*[a-z]*)") do
        table.insert(registers, register)
      end
    end
    return registers, true, operand
  end

  return {}, false, nil
end

-- Backward compatibility wrapper - returns first register for old code
local function extract_register_from_operand(operand)
  local regs, is_mem, mem_expr = extract_registers_from_operand(operand)
  if #regs > 0 then
    return regs[1], is_mem, mem_expr
  end
  return nil, false, nil
end

-- Parse instruction operands based on assembly syntax
local function parse_instruction_operands(instruction, syntax)
  local operands = {
    sources = {},  -- Registers/memory read by this instruction
    destinations = {}  -- Registers/memory written by this instruction
  }

  -- Remove instruction mnemonic to get operands
  -- Handle extra whitespace in instruction text
  instruction = trim(instruction)
  local mnemonic, operand_str = instruction:match("^([a-z]+[a-z0-9]*[qwlbsd]?)%s+(.*)$")
  if not operand_str then
        return operands
  end

  -- Split operands by comma, but respect parentheses
  local ops = {}
  local current_op = ""
  local paren_depth = 0

  for i = 1, #operand_str do
    local char = operand_str:sub(i, i)
    if char == "(" then
      paren_depth = paren_depth + 1
      current_op = current_op .. char
    elseif char == ")" then
      paren_depth = paren_depth - 1
      current_op = current_op .. char
    elseif char == "," and paren_depth == 0 then
      -- Only split on commas outside parentheses
      table.insert(ops, trim(current_op))
      current_op = ""
    else
      current_op = current_op .. char
    end
  end

  -- Add the last operand
  if current_op ~= "" then
    table.insert(ops, trim(current_op))
  end

  -- Simplified approach: use syntax rules regardless of specific instruction
  if syntax == "att" then
    -- AT&T syntax: generally source, destination
    -- Special cases for comparison instructions that only read
    if mnemonic:match("^(cmp|test|bt)") then
      -- Comparison instructions - all operands are sources (read-only)
      for _, op in ipairs(ops) do
        local regs, is_mem, mem_expr = extract_registers_from_operand(op)
        for _, reg in ipairs(regs) do
          table.insert(operands.sources, reg)
        end
      end
    elseif mnemonic:match("^push") then
      -- Push: reads the operand
      if ops[1] then
        local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
        for _, reg in ipairs(regs) do
          table.insert(operands.sources, reg)
        end
      end
    elseif mnemonic:match("^pop") then
      -- Pop: writes to the operand
      if ops[1] then
        local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
        for _, reg in ipairs(regs) do
          if not is_mem then
            table.insert(operands.destinations, reg)
          else
            table.insert(operands.sources, reg)  -- Address calculation registers
          end
        end
      end
    elseif #ops >= 2 then
      -- Standard two-operand AT&T: source, destination
      local src_regs, src_is_mem, src_mem = extract_registers_from_operand(ops[1])
      local dst_regs, dst_is_mem, dst_mem = extract_registers_from_operand(ops[2])
      
      -- Include ALL registers from source operand (including memory addressing registers)
      for _, reg in ipairs(src_regs) do
        table.insert(operands.sources, reg)
      end
      
      -- For destination operand, only include as destination if not memory access
      -- But include addressing registers as sources
      for _, reg in ipairs(dst_regs) do
        if not dst_is_mem then 
          table.insert(operands.destinations, reg)
          -- For read-modify-write operations, destination is also read
          if not mnemonic:match("^mov") and not mnemonic:match("^lea") then
            table.insert(operands.sources, reg)
          end
        else
          -- Memory addressing registers are sources (read to compute address)
          table.insert(operands.sources, reg)
        end
      end
    elseif #ops == 1 then
      -- Single operand instructions - assume it's modified (read+write)
      local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
      for _, reg in ipairs(regs) do
        if not is_mem then
          table.insert(operands.sources, reg)
          table.insert(operands.destinations, reg)
        else
          table.insert(operands.sources, reg)  -- Address calculation registers
        end
      end
    end
  else
    -- Intel syntax: generally destination, source
    if mnemonic:match("^(cmp|test|bt)") then
      -- Comparison instructions - all operands are sources (read-only)
      for _, op in ipairs(ops) do
        local regs, is_mem, mem_expr = extract_registers_from_operand(op)
        for _, reg in ipairs(regs) do
          table.insert(operands.sources, reg)
        end
      end
    elseif mnemonic:match("^push") then
      -- Push: reads the operand
      if ops[1] then
        local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
        for _, reg in ipairs(regs) do
          table.insert(operands.sources, reg)
        end
      end
    elseif mnemonic:match("^pop") then
      -- Pop: writes to the operand
      if ops[1] then
        local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
        for _, reg in ipairs(regs) do
          if not is_mem then
            table.insert(operands.destinations, reg)
          else
            table.insert(operands.sources, reg)  -- Address calculation registers
          end
        end
      end
    elseif #ops >= 2 then
      -- Standard two-operand: destination, source
      local dst_regs, dst_is_mem, dst_mem = extract_registers_from_operand(ops[1])
      local src_regs, src_is_mem, src_mem = extract_registers_from_operand(ops[2])
      
      -- Include ALL registers from source operand (including memory addressing registers)
      for _, reg in ipairs(src_regs) do
        table.insert(operands.sources, reg)
      end
      
      -- For destination operand, only include as destination if not memory access
      -- But include addressing registers as sources
      for _, reg in ipairs(dst_regs) do
        if not dst_is_mem then 
          table.insert(operands.destinations, reg)
          -- For read-modify-write operations, destination is also read
          if not mnemonic:match("^mov") and not mnemonic:match("^lea") then
            table.insert(operands.sources, reg)
          end
        else
          -- Memory addressing registers are sources (read to compute address)
          table.insert(operands.sources, reg)
        end
      end
    elseif #ops == 1 then
      -- Single operand instructions - assume it's modified (read+write)
      local regs, is_mem, mem_expr = extract_registers_from_operand(ops[1])
      for _, reg in ipairs(regs) do
        if not is_mem then
          table.insert(operands.sources, reg)
          table.insert(operands.destinations, reg)
        else
          table.insert(operands.sources, reg)  -- Address calculation registers
        end
      end
    end
  end
  
  return operands
end

-- Enhanced dependency detection with timing awareness
local function check_register_dependency(prev_instr, curr_instr, syntax)
  local prev_ops = parse_instruction_operands(prev_instr.instruction, syntax)
  local curr_ops = parse_instruction_operands(curr_instr.instruction, syntax)
  
  -- Key insight: Only consider it a dependency if the previous instruction
  -- is still executing when the current instruction is dispatched
  
  -- Check timing: if previous instruction finished before current dispatched, no dependency
  if prev_instr.timing.execution_end and curr_instr.timing.dispatch_cycle then
    if prev_instr.timing.execution_end < curr_instr.timing.dispatch_cycle then
      return false, nil  -- Previous finished before current started, no dependency
    end
  end
  
  -- Check for RAW dependencies: current instruction reads what previous wrote
  -- This is the main type of dependency that causes stalls
  for _, prev_dst in ipairs(prev_ops.destinations) do
    for _, curr_src in ipairs(curr_ops.sources) do
      if prev_dst == curr_src or are_aliased_registers(prev_dst, curr_src) then
        return true, "RAW"
      end
    end
  end
  
  return false, nil
end

-- Find dependencies between instructions using syntax-aware analysis
local function find_dependencies(instructions, syntax)
  local dependencies = {}
  
  for i, instr in ipairs(instructions) do
    dependencies[i] = {
      instruction = instr,
      depends_on = {},
      dependents = {},
      dependency_types = {},  -- Store the type of each dependency (RAW, WAW, WAR)
      dependency_registers = {}  -- Store which register each dependency is on
    }
  end
  
  -- Track the most recent instruction that wrote to each register
  local last_writer = {}
  
  for i, instr in ipairs(instructions) do
    local curr_ops = parse_instruction_operands(instr.instruction, syntax)
    
    -- Check dependencies: current instruction reads what was recently written
    for _, src_reg in ipairs(curr_ops.sources) do
      local writer_idx = last_writer[src_reg]
      if writer_idx then
        local writer_instr = instructions[writer_idx]
        
        -- Check timing: only dependency if writer still executing when current dispatches
        local has_timing_dependency = false
        if writer_instr.timing.execution_end and instr.timing.dispatch_cycle then
          if writer_instr.timing.execution_end >= instr.timing.dispatch_cycle then
            has_timing_dependency = true
          end
        else
          -- If we don't have timing info, assume dependency exists
          has_timing_dependency = true
        end
        
        if has_timing_dependency then
          table.insert(dependencies[i].depends_on, writer_idx)
          table.insert(dependencies[writer_idx].dependents, i)
          dependencies[i].dependency_types[writer_idx] = "RAW"
          dependencies[i].dependency_registers[writer_idx] = src_reg  -- Store the register
        end
      end
    end
    
    -- Update last writer for each register this instruction writes to
    for _, dst_reg in ipairs(curr_ops.destinations) do
      last_writer[dst_reg] = i
    end
  end
  
  return dependencies
end

-- Main function to analyze dependencies from LLVM-MCA output
function M.analyze_dependencies(llvm_mca_output)
  local instructions = {}
  local in_timeline = false
  
  -- Parse the output to extract timeline information
  for line in llvm_mca_output:gmatch("([^\n]*)\n?") do
    if line:match("Timeline view:") then
      in_timeline = true
    elseif in_timeline then
      -- Stop if we hit the next section
      if line:match("Average [Ww]ait times") or line:match("^Average Wait Time") then
        break
      end
      
      -- Skip header lines and empty lines
      if not line:match("^%s*$") and not line:match("Index%s+") and not line:match("^%s*[0-9]+") then
        local parsed = parse_timeline_line(line)
        if parsed then
          parsed.timing = analyze_timeline_pattern(parsed.timeline)
          table.insert(instructions, parsed)
        end
      end
    end
  end
  
  -- Detect assembly syntax from the instructions
  local syntax = detect_assembly_syntax(instructions)
  
  -- Debug: print some info about what we parsed
  print(string.format("Parsed %d instructions, detected %s syntax", #instructions, syntax))
  if #instructions > 0 then
    print("First few instructions:")
    for i = 1, math.min(3, #instructions) do
      print(string.format("  [%d] %s", instructions[i].index, instructions[i].instruction))
    end
  end
  
  -- Find dependencies between instructions using syntax-aware analysis
  local dependencies = find_dependencies(instructions, syntax)
  
  -- Debug: count dependencies found
  local dep_count = 0
  for _, dep_info in pairs(dependencies) do
    dep_count = dep_count + #dep_info.depends_on
  end
  print(string.format("Found %d total dependencies", dep_count))
  
  return {
    instructions = instructions,
    dependencies = dependencies,
    total_instructions = #instructions,
    assembly_syntax = syntax  -- Include detected syntax in results
  }
end

-- Get dependencies for a specific instruction index
function M.get_dependencies_for_instruction(analysis, instruction_index)
  if not analysis.dependencies[instruction_index] then
    return nil
  end
  
  local deps = analysis.dependencies[instruction_index]
  local result = {
    instruction = deps.instruction,
    depends_on = {},
    dependents = {}
  }
  
  -- Get detailed info for dependencies
  for _, dep_idx in ipairs(deps.depends_on) do
    if analysis.dependencies[dep_idx] then
      table.insert(result.depends_on, {
        index = dep_idx,
        instruction = analysis.dependencies[dep_idx].instruction
      })
    end
  end
  
  for _, dep_idx in ipairs(deps.dependents) do
    if analysis.dependencies[dep_idx] then
      table.insert(result.dependents, {
        index = dep_idx,
        instruction = analysis.dependencies[dep_idx].instruction
      })
    end
  end
  
  return result
end

-- Format dependency information for display
function M.format_dependencies(deps)
  if not deps then
    return "No dependency information available"
  end
  
  local lines = {}
  table.insert(lines, string.format("Instruction [%d]: %s", 
    deps.instruction.index, deps.instruction.instruction))
  table.insert(lines, "")
  
  if #deps.depends_on > 0 then
    table.insert(lines, "Depends on:")
    for _, dep in ipairs(deps.depends_on) do
      table.insert(lines, string.format("  [%d] %s", dep.index, dep.instruction.instruction))
    end
  else
    table.insert(lines, "No dependencies")
  end
  
  table.insert(lines, "")
  
  if #deps.dependents > 0 then
    table.insert(lines, "Dependents:")
    for _, dep in ipairs(deps.dependents) do
      table.insert(lines, string.format("  [%d] %s", dep.index, dep.instruction.instruction))
    end
  else
    table.insert(lines, "No dependents")
  end
  
  return table.concat(lines, "\n")
end

-- Debug function to test instruction parsing
function M.debug_instruction_parsing(instruction1, instruction2)
  local syntax = "att"  -- We know it's AT&T from the % symbols
  
  print("=== DEBUG INSTRUCTION PARSING ===")
  print("Instruction 1:", instruction1)
  print("Instruction 2:", instruction2)
  print("Syntax:", syntax)
  
  local ops1 = parse_instruction_operands(instruction1, syntax)
  local ops2 = parse_instruction_operands(instruction2, syntax)
  
  print("\nInstruction 1 operands:")
  print("  Sources:", table.concat(ops1.sources, ", "))
  print("  Destinations:", table.concat(ops1.destinations, ", "))
  
  print("\nInstruction 2 operands:")
  print("  Sources:", table.concat(ops2.sources, ", "))
  print("  Destinations:", table.concat(ops2.destinations, ", "))
  
  -- Create mock instruction objects for the dependency check
  local instr1 = {
    instruction = instruction1,
    timing = { execution_end = 5, dispatch_cycle = 0 }  -- Mock timing
  }
  local instr2 = {
    instruction = instruction2,
    timing = { execution_end = 10, dispatch_cycle = 3 }  -- Mock timing
  }
  
  local has_dep, dep_type = check_register_dependency(instr1, instr2, syntax)
  print("\nDependency check result:", has_dep, dep_type or "none")
  
  return has_dep, dep_type
end

-- Expose helper functions for use by other modules
M.parse_instruction_operands = parse_instruction_operands
M.are_aliased_registers = are_aliased_registers

return M 