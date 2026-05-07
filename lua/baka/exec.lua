-- baka.exec: thin wrapper around `git` invocations.
local M = {}

function M.git_raw(args, cwd)
  local cmd = { "git", "-C", cwd or vim.fn.getcwd() }
  vim.list_extend(cmd, args)
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    return false, "", res.stderr or ""
  end
  return true, res.stdout or "", ""
end

function M.git_lines(args, cwd)
  local ok, raw, err = M.git_raw(args, cwd)
  if not ok then return false, {}, err end
  return true, vim.split((raw:gsub("\n$", "")), "\n", { plain = true }), ""
end

return M
