-- baka.ui: floating window helpers themed via Baka* highlight groups.
local hl = require("baka.highlights")

local M = {}

local function longest(lines)
  local n = 0
  for _, l in ipairs(lines) do
    if #l > n then n = #l end
  end
  return n
end

local function scratch_buf(lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  if filetype then vim.bo[buf].filetype = filetype end
  return buf
end

local function bind_close_keys(buf, win)
  local close = function() pcall(vim.api.nvim_win_close, win, true) end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })
end

-- Centered floating window. Returns (win, buf).
function M.open_float(lines, opts)
  opts = opts or {}
  local buf = scratch_buf(lines, opts.filetype)
  local ui = vim.api.nvim_list_uis()[1]
  local width = opts.width
    or math.min(math.max(longest(lines) + 4, 60), math.floor(ui.width * 0.85))
  local height = opts.height
    or math.min(math.max(#lines, 5), math.floor(ui.height * 0.7))
  local win = vim.api.nvim_open_win(buf, opts.enter ~= false, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    title = opts.title and (" " .. opts.title .. " ") or nil,
    title_pos = opts.title and "left" or nil,
  })
  vim.wo[win].cursorline = opts.cursorline ~= false
  vim.wo[win].wrap = false
  vim.wo[win].winhighlight = hl.float_winhl
  bind_close_keys(buf, win)
  return win, buf
end

-- Cursor-anchored floating window that auto-closes on cursor movement.
function M.open_cursor_float(lines, opts)
  opts = opts or {}
  local buf = scratch_buf(lines, opts.filetype)
  local width = opts.width or math.min(longest(lines) + 2, 80)
  local height = opts.height or #lines
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    anchor = "NW",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = opts.title and (" " .. opts.title .. " ") or nil,
    title_pos = opts.title and "left" or nil,
    focusable = false,
  })
  vim.wo[win].wrap = false
  vim.wo[win].winhighlight = hl.float_winhl
  local group = vim.api.nvim_create_augroup("BakaCursorFloat" .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave", "InsertEnter" }, {
    group = group,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, win, true)
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
  return win, buf
end

-- Apply a list of { line, col_start, col_end, hl_group } highlights to a buffer
-- via the baka extmark namespace. Pass row 0-indexed.
function M.apply_highlights(buf, items)
  for _, h in ipairs(items) do
    pcall(vim.api.nvim_buf_set_extmark, buf, hl.ns, h[1], h[2], {
      end_col = h[3],
      hl_group = h[4],
    })
  end
end

return M
