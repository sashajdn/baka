-- baka.history: file or range commit history popup with scroll pagination.
local exec = require("baka.exec")
local ui = require("baka.ui")

local M = {}

M.config = { page_size = 20, max = 100 }

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local SHA_W    = 7
local DATE_W   = 10
local AUTHOR_W = 16
local GAP      = 2

local SHA_START     = 0
local DATE_START    = SHA_W + GAP
local AUTHOR_START  = DATE_START + DATE_W + GAP
local SUBJECT_START = AUTHOR_START + AUTHOR_W + GAP

local function branch_label(cwd)
  local ok, lines = exec.git_lines({ "rev-parse", "--abbrev-ref", "HEAD" }, cwd)
  if not ok or #lines == 0 then return nil end
  local b = lines[1]
  if b == "" or b == "HEAD" then return nil end
  return b
end

local function parse_log_lines(lines)
  local out = {}
  for _, line in ipairs(lines) do
    local sha, author, date, subject = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.*)$")
    if sha then
      out[#out + 1] = {
        sha = sha,
        author = author:sub(1, AUTHOR_W),
        date = date,
        subject = subject,
      }
    end
  end
  return out
end

local function build_rows_and_hls(entries, row_offset)
  local rows, hls = {}, {}
  for i, e in ipairs(entries) do
    rows[i] = string.format(
      "%-" .. SHA_W .. "s  %-" .. DATE_W .. "s  %-" .. AUTHOR_W .. "s  %s",
      e.sha:sub(1, SHA_W), e.date, e.author, e.subject)
    local row = row_offset + i - 1
    hls[#hls + 1] = { row, SHA_START,     SHA_START + SHA_W,         "BakaSha" }
    hls[#hls + 1] = { row, DATE_START,    DATE_START + DATE_W,       "BakaDate" }
    hls[#hls + 1] = { row, AUTHOR_START,  AUTHOR_START + AUTHOR_W,   "BakaAuthor" }
    hls[#hls + 1] = { row, SUBJECT_START, SUBJECT_START + #e.subject, "BakaSubject" }
  end
  return rows, hls
end

local function append_end_marker(buf, max_reached)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local total = vim.api.nvim_buf_line_count(buf)
  local label = max_reached and "(max reached)" or "(end of history)"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, total, total, false, { "", label })
  vim.bo[buf].modifiable = false
  ui.apply_highlights(buf, { { total + 1, 0, #label, "BakaHint" } })
end

local function build_log_args(file, range, n, skip)
  local args = { "log", "-n", tostring(n), "--skip", tostring(skip),
    "--date=short", "--pretty=format:%h%x09%an%x09%ad%x09%s" }
  if range then
    args[#args + 1] = "--no-patch"
    args[#args + 1] = string.format("-L%d,%d:%s", range[1], range[2], file)
  else
    args[#args + 1] = "--"
    args[#args + 1] = file
  end
  return args
end

-- Show history for the current file (or visual range via opts.range).
-- Loads M.config.page_size commits initially, then auto-fetches more as the
-- cursor scrolls toward the bottom, up to M.config.max in total.
function M.show(opts)
  opts = opts or {}
  local cur_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(cur_buf)
  if file == "" then
    vim.notify("baka: buffer is not a file", vim.log.levels.WARN)
    return
  end
  local cwd = vim.fn.fnamemodify(file, ":h")
  local range = opts.range

  local page_size = opts.page_size or M.config.page_size
  local max = opts.max or M.config.max

  local entries = {}
  local fetched = 0
  local loading = false
  local exhausted = false

  local ok, lines, err = exec.git_lines(build_log_args(file, range, page_size, 0), cwd)
  if not ok then
    vim.notify("baka: log failed: " .. err, vim.log.levels.WARN)
    return
  end
  local initial = parse_log_lines(lines)
  if #initial == 0 then
    vim.notify("baka: no commits", vim.log.levels.INFO)
    return
  end
  vim.list_extend(entries, initial)
  fetched = #initial

  local rows, hls = build_rows_and_hls(entries, 0)

  local branch = branch_label(cwd)
  local title = string.format(
    "history %s%s%s",
    vim.fn.fnamemodify(file, ":t"),
    range and string.format(" L%d-%d", range[1], range[2]) or "",
    branch and (" [" .. branch .. "]") or "")

  local win, hbuf = ui.open_float(rows, { title = title, filetype = "baka-log" })
  ui.apply_highlights(hbuf, hls)

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local e = entries[lnum]
    if not e then return end
    M.show_commit(e.sha, file, cwd)
  end, { buffer = hbuf, nowait = true, silent = true })

  -- Lazy-load more entries as the cursor approaches the bottom of the popup.
  local group = vim.api.nvim_create_augroup("BakaHistory" .. hbuf, { clear = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = hbuf,
    callback = function()
      if loading or exhausted or fetched >= max then return end
      if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(hbuf) then return end
      local lnum = vim.api.nvim_win_get_cursor(win)[1]
      local total = vim.api.nvim_buf_line_count(hbuf)
      if lnum < total - 2 then return end

      loading = true
      local remaining = max - fetched
      local n = math.min(page_size, remaining)
      local ok2, more_lines = exec.git_lines(build_log_args(file, range, n, fetched), cwd)
      loading = false
      if not ok2 then
        exhausted = true
        return
      end
      local more = parse_log_lines(more_lines)
      if #more == 0 then
        exhausted = true
        append_end_marker(hbuf, false)
        return
      end

      local more_rows, more_hls = build_rows_and_hls(more, #entries)
      vim.bo[hbuf].modifiable = true
      vim.api.nvim_buf_set_lines(hbuf, total, total, false, more_rows)
      vim.bo[hbuf].modifiable = false
      vim.list_extend(entries, more)
      fetched = fetched + #more
      ui.apply_highlights(hbuf, more_hls)

      if fetched >= max then
        exhausted = true
        append_end_marker(hbuf, true)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = hbuf,
    once = true,
    callback = function() pcall(vim.api.nvim_del_augroup_by_id, group) end,
  })
end

-- Show a single commit's diff (scoped to file if given) in a centered float.
function M.show_commit(sha, file, cwd)
  local args = { "show", "--stat", "--patch", sha }
  if file then
    args[#args + 1] = "--"
    args[#args + 1] = file
  end
  local ok, lines, err = exec.git_lines(args, cwd or vim.fn.getcwd())
  if not ok then
    vim.notify("baka: show failed: " .. err, vim.log.levels.WARN)
    return
  end
  ui.open_float(lines, {
    title = "commit " .. sha:sub(1, 7),
    filetype = "git",
  })
end

return M
