local M = {}

local ns_id = vim.api.nvim_create_namespace('macan_markers')
local markers = {}

local function set_marker(bufnr, marker_type, line)
  markers[bufnr] = markers[bufnr] or {}
  markers[bufnr][marker_type] = line
  -- Clear previous virtual text for this marker type
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  -- Add virtual text for start marker
  if markers[bufnr].start then
    vim.api.nvim_buf_set_virtual_text(bufnr, ns_id, markers[bufnr].start, {{'▶ LLVM_MCA_START', 'WarningMsg'}}, {})
  end
  -- Add virtual text for end marker
  if markers[bufnr].end_ then
    vim.api.nvim_buf_set_virtual_text(bufnr, ns_id, markers[bufnr].end_, {{'◀ LLVM_MCA_END', 'WarningMsg'}}, {})
  end
end

function M.set_start()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  set_marker(bufnr, 'start', line)
  vim.notify('Set LLVM_MCA_START at line ' .. (line + 1), vim.log.levels.INFO)
end

function M.set_end()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  set_marker(bufnr, 'end_', line)
  vim.notify('Set LLVM_MCA_END at line ' .. (line + 1), vim.log.levels.INFO)
end

function M.clear_markers()
  local bufnr = vim.api.nvim_get_current_buf()
  markers[bufnr] = nil
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  vim.notify('Cleared LLVM_MCA_START and LLVM_MCA_END markers', vim.log.levels.INFO)
end

function M.get_markers(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return markers[bufnr] or {}
end

return M 