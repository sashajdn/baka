-- baka.diff: side-by-side diff of the current file vs a ref (default master).
-- Uses native vim diff mode with theme-aligned, opaque BakaDiff* highlights
-- scoped to the diff windows via winhighlight. Auto-refreshes the base side
-- when the head window navigates to a different file.
local exec = require("baka.exec")

local M = {}

-- One session per tabpage.
local sessions = {}

local DIFF_WINHL = table.concat({
  "DiffAdd:BakaDiffAdd",
  "DiffDelete:BakaDiffDelete",
  "DiffChange:BakaDiffChange",
  "DiffText:BakaDiffText",
  "Normal:BakaDiffNormal",
}, ",")

local function repo_root(cwd)
  local ok, lines = exec.git_lines({ "rev-parse", "--show-toplevel" }, cwd)
  if not ok or #lines == 0 then return nil end
  return lines[1]
end

local function ref_exists(ref, cwd)
  local ok = exec.git_lines({ "rev-parse", "--verify", "--quiet", ref }, cwd)
  return ok
end

local function detect_default_base(cwd)
  for _, r in ipairs({ "master", "main", "origin/master", "origin/main" }) do
    if ref_exists(r, cwd) then return r end
  end
  return nil
end

local function show_at_ref(ref, rel, cwd)
  local ok, lines = exec.git_lines({ "show", ref .. ":" .. rel }, cwd)
  return ok and lines or nil
end

local function apply_diff_chrome(win)
  vim.wo[win].winhighlight = DIFF_WINHL
  vim.api.nvim_win_call(win, function()
    vim.opt_local.fillchars:append({ diff = " " })
  end)
end

local function set_winbars(s, file, added)
  if not vim.api.nvim_win_is_valid(s.base_win) or not vim.api.nvim_win_is_valid(s.head_win) then
    return
  end
  local tail = vim.fn.fnamemodify(file, ":t")
  vim.wo[s.base_win].winbar =
    string.format(" %s · %s%s", s.base_ref, tail, added and " (added)" or "")
  vim.wo[s.head_win].winbar =
    string.format(" HEAD · %s%%{&modified ? ' *' : ''}", tail)
end

local function refresh_base(s, head_buf)
  local file = vim.api.nvim_buf_get_name(head_buf)
  if file == "" then return end
  local cwd = vim.fn.fnamemodify(file, ":h")
  local root = repo_root(cwd); if not root then return end
  local rel = file:sub(#root + 2)

  local base_lines = show_at_ref(s.base_ref, rel, cwd)
  local added = base_lines == nil
  base_lines = base_lines or {}

  vim.bo[s.base_buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.base_buf, 0, -1, false, base_lines)
  vim.bo[s.base_buf].modifiable = false
  vim.bo[s.base_buf].filetype = vim.bo[head_buf].filetype

  set_winbars(s, file, added)
  pcall(vim.cmd, "diffupdate")
end

local function close_session(tab)
  local s = sessions[tab]
  if not s then return end
  sessions[tab] = nil
  if s.augroup then pcall(vim.api.nvim_del_augroup_by_id, s.augroup) end
  if vim.api.nvim_win_is_valid(s.head_win) then
    vim.api.nvim_win_call(s.head_win, function() pcall(vim.cmd, "diffoff") end)
    pcall(function()
      vim.wo[s.head_win].winhighlight = ""
      vim.wo[s.head_win].winbar = ""
    end)
  end
  if vim.api.nvim_win_is_valid(s.base_win) then
    pcall(vim.api.nvim_win_close, s.base_win, true)
  end
end

-- Public: diff current file vs `ref`. nil = auto-detect (master/main/origin).
-- If a session is already open in this tab, closes it first and re-opens
-- against the (possibly new) current file.
function M.against(ref)
  local tab = vim.api.nvim_get_current_tabpage()
  if sessions[tab] then close_session(tab) end

  local head_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(head_buf)
  if file == "" then
    vim.notify("baka: buffer is not a file", vim.log.levels.WARN)
    return
  end
  local cwd = vim.fn.fnamemodify(file, ":h")
  local root = repo_root(cwd)
  if not root then
    vim.notify("baka: not in a git repo", vim.log.levels.WARN)
    return
  end
  local rel = file:sub(#root + 2)

  local base_ref = ref or detect_default_base(cwd)
  if not base_ref then
    vim.notify("baka: no master/main found", vim.log.levels.WARN)
    return
  end
  if ref and not ref_exists(base_ref, cwd) then
    vim.notify("baka: ref not found: " .. base_ref, vim.log.levels.WARN)
    return
  end

  local base_lines = show_at_ref(base_ref, rel, cwd)
  local added = base_lines == nil
  base_lines = base_lines or {}

  local base_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(base_buf, 0, -1, false, base_lines)
  vim.bo[base_buf].buftype = "nofile"
  vim.bo[base_buf].bufhidden = "wipe"
  vim.bo[base_buf].modifiable = false
  vim.bo[base_buf].filetype = vim.bo[head_buf].filetype

  local head_win = vim.api.nvim_get_current_win()
  vim.cmd("leftabove vsplit")
  local base_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(base_win, base_buf)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(head_win)
  vim.cmd("diffthis")

  apply_diff_chrome(base_win)
  apply_diff_chrome(head_win)

  local session = {
    tab = tab,
    base_win = base_win,
    head_win = head_win,
    base_buf = base_buf,
    base_ref = base_ref,
  }
  sessions[tab] = session

  set_winbars(session, file, added)

  local augroup = vim.api.nvim_create_augroup("BakaDiff_t" .. tab, { clear = true })
  session.augroup = augroup

  -- Auto-refresh: when the head window's buffer changes, refresh the base side
  -- to show the new file at the same ref.
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function(args)
      local s = sessions[tab]
      if not s then return end
      if vim.api.nvim_get_current_win() ~= s.head_win then return end
      if not args.buf or args.buf == s.base_buf then return end
      if not vim.api.nvim_buf_is_valid(args.buf) then return end
      if vim.api.nvim_buf_get_name(args.buf) == "" then return end
      refresh_base(s, args.buf)
    end,
  })

  -- Tear down if either side is closed externally.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    callback = function(args)
      local s = sessions[tab]
      if not s then return end
      local closed = tonumber(args.match)
      if closed == s.base_win or closed == s.head_win then
        close_session(tab)
      end
    end,
  })

  -- q in the base buffer closes the diff. Don't bind q on head_buf — that's
  -- the user's actual file buffer.
  vim.keymap.set("n", "q", function() close_session(tab) end,
    { buffer = base_buf, nowait = true, silent = true })

  -- ]q / [q from the base side would try to load qflist files into a
  -- nofile/nomodifiable buffer. Trampoline through the head window first.
  local function via_head(cmd)
    return function()
      if vim.api.nvim_win_is_valid(session.head_win) then
        vim.api.nvim_set_current_win(session.head_win)
      end
      pcall(vim.cmd, cmd .. " | normal! zz")
    end
  end
  vim.keymap.set("n", "]q", via_head("cnext"),
    { buffer = base_buf, nowait = true, silent = true, desc = "Next quickfix item" })
  vim.keymap.set("n", "[q", via_head("cprev"),
    { buffer = base_buf, nowait = true, silent = true, desc = "Previous quickfix item" })
end

function M.close()
  close_session(vim.api.nvim_get_current_tabpage())
end

-- Public: toggle diff for current file vs `ref`. Bound to <leader>bd.
function M.toggle(ref)
  local tab = vim.api.nvim_get_current_tabpage()
  if sessions[tab] then
    close_session(tab)
    return
  end
  M.against(ref)
end

-- Public: populate the quickfix list with all files changed vs `ref` (default
-- master), open diff on the first one. Walking the qflist (]q / [q / :cnext)
-- drives the diff auto-refresh — the PR-walk workflow.
function M.changes(ref)
  local cur_buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(cur_buf)
  local cwd = file ~= "" and vim.fn.fnamemodify(file, ":h") or vim.fn.getcwd()
  local root = repo_root(cwd)
  if not root then
    vim.notify("baka: not in a git repo", vim.log.levels.WARN)
    return
  end

  local base = ref or detect_default_base(cwd)
  if not base then
    vim.notify("baka: no master/main found", vim.log.levels.WARN)
    return
  end
  if ref and not ref_exists(base, cwd) then
    vim.notify("baka: ref not found: " .. base, vim.log.levels.WARN)
    return
  end

  -- Use merge-base so committed + staged + unstaged changes all appear.
  local ok_mb, mb_lines = exec.git_lines({ "merge-base", base, "HEAD" }, cwd)
  if not ok_mb or #mb_lines == 0 then
    vim.notify("baka: no merge-base with " .. base, vim.log.levels.WARN)
    return
  end
  local mb = mb_lines[1]

  -- --diff-filter=d excludes deletions (those files don't exist on disk so
  -- the diff view can't open them).
  local ok, lines = exec.git_lines({
    "diff", "--name-status", "--diff-filter=d", mb,
  }, cwd)
  if not ok then
    vim.notify("baka: git diff failed", vim.log.levels.WARN)
    return
  end

  local items = {}
  for _, line in ipairs(lines) do
    local status, path = line:match("^(%S+)%s+(.+)$")
    if status and path then
      items[#items + 1] = {
        filename = root .. "/" .. path,
        lnum = 1,
        col = 1,
        text = string.format("[%s] %s", status, path),
      }
    end
  end

  if #items == 0 then
    vim.notify("baka: no changes vs " .. base, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, " ", {
    title = string.format("baka changes vs %s (%d files)", base, #items),
    items = items,
  })

  -- Jump to first changed file, then open diff in that window. M.against
  -- handles closing any pre-existing session.
  vim.cmd("cfirst")
  M.against(base)

  -- Surface the qflist without stealing focus from the head window.
  local stay = vim.api.nvim_get_current_win()
  vim.cmd("copen")
  if vim.api.nvim_win_is_valid(stay) then
    vim.api.nvim_set_current_win(stay)
  end
end

return M
