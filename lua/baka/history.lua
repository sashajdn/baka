-- baka.history: file or range commit history popup, plus single-commit viewer.
local exec = require("baka.exec")
local ui = require("baka.ui")

local M = {}

local SHA_W    = 7
local DATE_W   = 10
local AUTHOR_W = 16
local GAP      = 2

-- Show last K commits touching the current file. With opts.range = {s, e},
-- restrict to that line range via `git log -L`.
function M.show(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("baka: buffer is not a file", vim.log.levels.WARN)
    return
  end
  local cwd = vim.fn.fnamemodify(file, ":h")
  local k = opts.k or 20

  local args = { "log", "-n", tostring(k), "--date=short",
    "--pretty=format:%h%x09%an%x09%ad%x09%s" }
  if opts.range then
    args[#args + 1] = "--no-patch"
    args[#args + 1] = string.format("-L%d,%d:%s", opts.range[1], opts.range[2], file)
  else
    args[#args + 1] = "--"
    args[#args + 1] = file
  end

  local ok, lines, err = exec.git_lines(args, cwd)
  if not ok then
    vim.notify("baka: log failed: " .. err, vim.log.levels.WARN)
    return
  end

  local entries = {}
  for _, line in ipairs(lines) do
    local sha, author, date, subject = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.*)$")
    if sha then
      entries[#entries + 1] = {
        sha = sha,
        author = author:sub(1, AUTHOR_W),
        date = date,
        subject = subject,
      }
    end
  end

  if #entries == 0 then
    vim.notify("baka: no commits", vim.log.levels.INFO)
    return
  end

  local rows, hls = {}, {}
  local sha_start     = 0
  local date_start    = SHA_W + GAP
  local author_start  = date_start + DATE_W + GAP
  local subject_start = author_start + AUTHOR_W + GAP
  for i, e in ipairs(entries) do
    rows[i] = string.format(
      "%-" .. SHA_W .. "s  %-" .. DATE_W .. "s  %-" .. AUTHOR_W .. "s  %s",
      e.sha:sub(1, SHA_W), e.date, e.author, e.subject)
    local row = i - 1
    hls[#hls + 1] = { row, sha_start,     sha_start + SHA_W,         "BakaSha" }
    hls[#hls + 1] = { row, date_start,    date_start + DATE_W,       "BakaDate" }
    hls[#hls + 1] = { row, author_start,  author_start + AUTHOR_W,   "BakaAuthor" }
    hls[#hls + 1] = { row, subject_start, subject_start + #e.subject, "BakaSubject" }
  end

  local title = opts.range
    and string.format("history L%d-%d %s", opts.range[1], opts.range[2], vim.fn.fnamemodify(file, ":t"))
    or string.format("history %s", vim.fn.fnamemodify(file, ":t"))
  local win, hbuf = ui.open_float(rows, { title = title, filetype = "baka-log" })
  ui.apply_highlights(hbuf, hls)

  vim.keymap.set("n", "<CR>", function()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local e = entries[lnum]
    if not e then return end
    M.show_commit(e.sha, file, cwd)
  end, { buffer = hbuf, nowait = true, silent = true })
end

-- Show a single commit's diff (scoped to file if given) in a centered float.
-- The 'git' filetype carries neovim's bundled syntax highlighting.
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
