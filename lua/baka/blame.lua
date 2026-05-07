-- baka.blame: cursor-anchored line popup + full-file LHS scroll-bound split.
local ui = require("baka.ui")

local M = {}

-- Layout constants (must agree with format strings below).
local SHA_W    = 7
local AUTHOR_W = 12
local DATE_W   = 10
local GAP      = 2

local function fmt_date(ts)
  return ts and os.date("%Y-%m-%d", ts) or "?"
end

-- Parse `git blame --porcelain` output for a single line.
local function parse_porcelain_line(text)
  local info = {}
  local first = true
  for line in vim.gsplit(text, "\n", { plain = true }) do
    if first then
      info.sha = line:match("^(%x+)")
      first = false
    elseif line:sub(1, 1) ~= "\t" then
      local k, v = line:match("^(%S+) (.*)$")
      if k == "author" then info.author = v
      elseif k == "author-time" then info.author_time = tonumber(v)
      elseif k == "summary" then info.summary = v
      end
    end
  end
  return info
end

-- Parse `git blame --line-porcelain` output for a whole file.
local function parse_file_blame(text)
  local entries, cur = {}, {}
  for line in vim.gsplit(text, "\n", { plain = true }) do
    if line:sub(1, 1) == "\t" then
      entries[#entries + 1] = cur
      cur = {}
    elseif not cur.sha and line:match("^[0-9a-f]+ %d+ %d+") then
      cur.sha = line:match("^([0-9a-f]+)")
    else
      local k, v = line:match("^(%S+) (.*)$")
      if k == "author" then cur.author = v
      elseif k == "author-time" then cur.author_time = tonumber(v)
      elseif k == "summary" then cur.summary = v
      end
    end
  end
  return entries
end

local function buf_info_or_warn()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("baka: buffer is not a file", vim.log.levels.WARN)
    return nil
  end
  return { buf = buf, file = file, cwd = vim.fn.fnamemodify(file, ":h") }
end

-- gb: blame current line in cursor-anchored popup.
function M.line()
  local info = buf_info_or_warn()
  if not info then return end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local args = { "blame", "-L", lnum .. "," .. lnum, "--porcelain" }
  local stdin
  if vim.bo[info.buf].modified then
    args[#args + 1] = "--contents"
    args[#args + 1] = "-"
    stdin = table.concat(vim.api.nvim_buf_get_lines(info.buf, 0, -1, false), "\n")
  end
  args[#args + 1] = "--"
  args[#args + 1] = info.file

  local cmd = { "git", "-C", info.cwd }
  vim.list_extend(cmd, args)
  local sysopts = { text = true }
  if stdin then sysopts.stdin = stdin end
  local res = vim.system(cmd, sysopts):wait()
  if res.code ~= 0 then
    vim.notify("baka: blame failed: " .. (res.stderr or ""), vim.log.levels.WARN)
    return
  end

  local b = parse_porcelain_line(res.stdout or "")
  if not b.sha then return end

  local lines, hls = {}, {}
  if b.sha:match("^0+$") then
    lines[1] = "Not Committed Yet"
    hls[#hls + 1] = { 0, 0, #lines[1], "BakaUncommitted" }
  else
    local sha7 = b.sha:sub(1, 7)
    local author = b.author or "?"
    local date = fmt_date(b.author_time)
    local header = string.format("%s  %s  %s", sha7, author, date)
    lines[1] = header
    -- highlight the header by computed offsets
    local col = 0
    hls[#hls + 1] = { 0, col, col + #sha7, "BakaSha" }; col = col + #sha7 + 2
    hls[#hls + 1] = { 0, col, col + #author, "BakaAuthor" }; col = col + #author + 2
    hls[#hls + 1] = { 0, col, col + #date, "BakaDate" }
    if b.summary and b.summary ~= "" then
      lines[#lines + 1] = ""
      lines[#lines + 1] = b.summary
      hls[#hls + 1] = { #lines - 1, 0, #b.summary, "BakaSubject" }
    end
  end
  if vim.bo[info.buf].modified then
    lines[#lines + 1] = ""
    local note = "(buffer modified)"
    lines[#lines + 1] = note
    hls[#hls + 1] = { #lines - 1, 0, #note, "BakaHint" }
  end

  local _, buf = ui.open_cursor_float(lines, { title = "blame" })
  ui.apply_highlights(buf, hls)
end

-- Build one row of the LHS column: "<sha7>  <author12>  <date>"
local function fmt_blame_row(e)
  local sha = (e.sha or ""):sub(1, SHA_W)
  local author = (e.author or "?"):sub(1, AUTHOR_W)
  return string.format(
    "%-" .. SHA_W .. "s  %-" .. AUTHOR_W .. "s  %s",
    sha, author, fmt_date(e.author_time))
end

-- gB: full-file blame as a left-side, scroll-bound split.
function M.file()
  local info = buf_info_or_warn()
  if not info then return end
  local res = vim.system({
    "git", "-C", info.cwd, "blame", "--line-porcelain", "--", info.file,
  }, { text = true }):wait()
  if res.code ~= 0 then
    vim.notify("baka: blame failed: " .. (res.stderr or ""), vim.log.levels.WARN)
    return
  end

  local entries = parse_file_blame(res.stdout or "")
  if #entries == 0 then return end

  local rows, hls = {}, {}
  local sha_start    = 0
  local author_start = SHA_W + GAP
  local date_start   = author_start + AUTHOR_W + GAP
  for i, e in ipairs(entries) do
    rows[i] = fmt_blame_row(e)
    local row = i - 1
    local uncommitted = e.sha and e.sha:match("^0+$")
    hls[#hls + 1] = { row, sha_start, sha_start + SHA_W,
      uncommitted and "BakaUncommitted" or "BakaSha" }
    hls[#hls + 1] = { row, author_start, author_start + AUTHOR_W, "BakaAuthor" }
    hls[#hls + 1] = { row, date_start, date_start + DATE_W, "BakaDate" }
  end

  local code_win = vim.api.nvim_get_current_win()
  local code_line = vim.api.nvim_win_get_cursor(code_win)[1]
  local width = SHA_W + GAP + AUTHOR_W + GAP + DATE_W

  vim.cmd("topleft " .. width .. "vsplit")
  local blame_win = vim.api.nvim_get_current_win()
  local blame_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(blame_win, blame_buf)
  vim.api.nvim_buf_set_lines(blame_buf, 0, -1, false, rows)
  vim.bo[blame_buf].modifiable = false
  vim.bo[blame_buf].bufhidden = "wipe"
  vim.bo[blame_buf].filetype = "baka-blame"

  vim.wo[blame_win].number = false
  vim.wo[blame_win].relativenumber = false
  vim.wo[blame_win].signcolumn = "no"
  vim.wo[blame_win].foldcolumn = "0"
  vim.wo[blame_win].winfixwidth = true
  vim.wo[blame_win].cursorline = true
  vim.wo[blame_win].wrap = false

  vim.wo[blame_win].scrollbind = true
  vim.wo[code_win].scrollbind = true
  vim.api.nvim_win_set_cursor(blame_win, { math.min(code_line, #rows), 0 })
  vim.cmd("syncbind")

  ui.apply_highlights(blame_buf, hls)

  local close = function()
    if vim.api.nvim_win_is_valid(code_win) then
      vim.wo[code_win].scrollbind = false
    end
    pcall(vim.api.nvim_win_close, blame_win, true)
  end
  vim.keymap.set("n", "q", close, { buffer = blame_buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = blame_buf, nowait = true, silent = true })
  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(blame_win)[1]
    local e = entries[lnum]
    if not e or not e.sha or e.sha:match("^0+$") then return end
    require("baka.history").show_commit(e.sha, info.file, info.cwd)
  end, { buffer = blame_buf, nowait = true, silent = true })
end

return M
