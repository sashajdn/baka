-- baka.remote: open the current line (or visual range) in the browser
-- on the repo's remote. Resolves SSH host aliases (~/.ssh/config) so
-- enterprise SSO setups like `git@org-sso:org/repo` work correctly.
local exec = require("baka.exec")

local M = {}

M.config = { host_map = {} }

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Parse ~/.ssh/config and return a map of `Host` alias -> `HostName` value.
-- Wildcards and Match-blocks are ignored. Does not perform `Include`.
local cached_ssh_map
local function ssh_host_map()
  if cached_ssh_map then return cached_ssh_map end
  local map = {}
  local path = vim.fn.expand("~/.ssh/config")
  if vim.fn.filereadable(path) == 0 then
    cached_ssh_map = map
    return map
  end
  local current_hosts = {}
  for raw in io.lines(path) do
    local line = raw:gsub("^%s+", ""):gsub("%s*#.*$", "")
    if line ~= "" then
      local key, val = line:match("^(%S+)%s+(.+)$")
      if key then
        key = key:lower()
        val = val:gsub("%s+$", "")
        if key == "host" then
          current_hosts = {}
          for h in val:gmatch("%S+") do
            if not h:match("[%*%?]") then
              current_hosts[#current_hosts + 1] = h
            end
          end
        elseif key == "hostname" then
          for _, h in ipairs(current_hosts) do
            map[h] = val
          end
        end
      end
    end
  end
  cached_ssh_map = map
  return map
end

local function resolve_host(host)
  return (M.config.host_map and M.config.host_map[host])
    or ssh_host_map()[host]
    or host
end

local function remote_url(cwd)
  local ok, lines = exec.git_lines({ "remote", "get-url", "origin" }, cwd)
  if not ok or #lines == 0 then return nil end
  local url = lines[1]

  -- git@host:org/repo  ->  https://<resolved-host>/org/repo
  local host, path = url:match("^git@([^:]+):(.+)$")
  if host then
    url = "https://" .. resolve_host(host) .. "/" .. path
  else
    -- ssh://git@host/org/repo  ->  https://<resolved-host>/org/repo
    local h2, p2 = url:match("^ssh://git@([^/]+)/(.+)$")
    if h2 then
      url = "https://" .. resolve_host(h2) .. "/" .. p2
    end
  end

  return (url:gsub("%.git$", ""))
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
