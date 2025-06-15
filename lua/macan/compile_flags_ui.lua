local M = {}

local custom_flags = {}

function M.get_custom_flags(filepath)
  return custom_flags[filepath]
end

function M.set_custom_flags(filepath, flags)
  custom_flags[filepath] = flags
end

function M.edit_flags_for_file(filepath, default_flags, on_save)
  local current_flags = custom_flags[filepath] or default_flags
  
  -- Create buffer for the floating window
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Calculate window size and position
  local width = math.floor(vim.o.columns * 0.8)
  local height = 8
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Edit Compile Flags ',
    title_pos = 'center',
  })
  
  -- Set buffer content
  local lines = {}
  -- Add header
  table.insert(lines, '# Edit compile flags for: ' .. vim.fn.fnamemodify(filepath, ':t'))
  table.insert(lines, '# Press <Ctrl-s> to save, <Esc> to cancel')
  table.insert(lines, '')
  
  -- Split the flags into multiple lines if they're too long
  local flag_lines = {}
  local current_line = ''
  for word in current_flags:gmatch('%S+') do
    if #current_line + #word + 1 > width - 4 then
      if current_line ~= '' then
        table.insert(flag_lines, current_line)
        current_line = word
      else
        table.insert(flag_lines, word)
      end
    else
      if current_line == '' then
        current_line = word
      else
        current_line = current_line .. ' ' .. word
      end
    end
  end
  if current_line ~= '' then
    table.insert(flag_lines, current_line)
  end
  
  -- Add flag lines to buffer
  for _, line in ipairs(flag_lines) do
    table.insert(lines, line)
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'sh')
  
  -- Position cursor at the start of the flags (skip header lines)
  vim.api.nvim_win_set_cursor(win, {4, 0})
  
  -- Set up keymaps for the buffer
  local function save_and_close()
    -- Get all lines except the header (first 3 lines)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 3, -1, false)
    -- Join all flag lines back together
    local new_flags = table.concat(all_lines, ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    
    if new_flags ~= '' then
      custom_flags[filepath] = new_flags
      if on_save then 
        on_save(new_flags) 
      end
      vim.notify('Saved custom compile flags:\n' .. new_flags, vim.log.levels.INFO)
    else
      vim.notify('Empty flags - clearing custom flags for this file.', vim.log.levels.WARN)
      custom_flags[filepath] = nil
    end
    
    vim.api.nvim_win_close(win, true)
  end
  
  local function cancel_and_close()
    vim.notify('Cancelled editing compile flags.', vim.log.levels.INFO)
    vim.api.nvim_win_close(win, true)
  end
  
  -- Set up buffer-local keymaps
  vim.api.nvim_buf_set_keymap(buf, 'n', '<C-s>', '', {
    noremap = true,
    silent = true,
    callback = save_and_close
  })
  vim.api.nvim_buf_set_keymap(buf, 'i', '<C-s>', '', {
    noremap = true,
    silent = true,
    callback = save_and_close
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
    noremap = true,
    silent = true,
    callback = cancel_and_close
  })
  
  -- Auto-close on buffer leave
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        cancel_and_close()
      end
    end
  })
end

function M.show_current_flags(filepath, default_flags)
  local current_flags = custom_flags[filepath]
  if current_flags then
    vim.notify('Custom flags for this file:\n' .. current_flags, vim.log.levels.INFO)
  else
    vim.notify('No custom flags set. Using default:\n' .. default_flags, vim.log.levels.INFO)
  end
end

function M.clear_custom_flags(filepath)
  custom_flags[filepath] = nil
  vim.notify('Cleared custom compile flags for this file.', vim.log.levels.INFO)
end

return M 