-- baka.remote: open the current line (or visual range) in the browser
-- on the repo's remote. Supports GitHub-style and GitLab-style URLs.
local exec = require("baka.exec")

local M = {}

local function remote_url(cwd)
  local ok, lines = exec.git_lines({ "remote", "get-url", "origin" }, cwd)
  if not ok or #lines == 0 then return nil end
  local url = lines[1]
  url = url:gsub("^git@([^:]+):", "https://%1/")
  url = url:gsub("%.git$", "")
  return url
end

local function head_sha(cwd)
  local ok, lines = exec.git_lines({ "rev-parse", "HEAD" }, cwd)
  if not ok or #lines == 0 then return nil end
  return lines[1]
end

local function repo_root(cwd)
  local ok, lines = exec.git_lines({ "rev-parse", "--show-toplevel" }, cwd)
  if not ok or #lines == 0 then return nil end
  return lines[1]
end

local function visual_range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local s = vim.fn.getpos("v")[2]
    local e = vim.fn.getpos(".")[2]
    if s > e then s, e = e, s end
    return s, e
  end
  local l = vim.fn.line(".")
  return l, l
end

function M.open()
  local file = vim.fn.expand("%:p")
  if file == "" then return end
  local cwd = vim.fn.fnamemodify(file, ":h")
  local root = repo_root(cwd); if not root then return end
  local remote = remote_url(cwd); if not remote then return end
  local ref = head_sha(cwd) or "HEAD"
  local rel = file:sub(#root + 2)

  local s, e = visual_range()

  local url
  if remote:match("gitlab%.") then
    url = string.format("%s/-/blob/%s/%s#L%d", remote, ref, rel, s)
    if e ~= s then url = url .. "-" .. e end
  else
    url = string.format("%s/blob/%s/%s#L%d", remote, ref, rel, s)
    if e ~= s then url = url .. "-L" .. e end
  end

  local opener
  if vim.fn.has("mac") == 1 then
    opener = { "open", url }
  else
    opener = { os.getenv("BROWSER") or "xdg-open", url }
  end
  vim.fn.jobstart(opener, { detach = true })
end

return M
