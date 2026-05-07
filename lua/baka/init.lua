-- baka.nvim — small, dependency-free git overlay for Neovim.
local M = {}

local defaults = {
  keymaps = {
    blame_line = "<leader>bb",
    blame_file = "<leader>bB",
    history    = "<leader>bh",
    remote     = "<leader>bo",
  },
  remote = {
    -- Map SSH host aliases (from ~/.ssh/config) to real hostnames so URL
    -- generation works for SSO setups. Auto-resolved from ~/.ssh/config too;
    -- entries here take precedence.
    host_map = {},
  },
}

M.config = defaults

local function set_keymaps(k)
  local map = vim.keymap.set
  if k.blame_line then
    map("n", k.blame_line, function() require("baka.blame").line() end,
      { desc = "Baka git blame line" })
  end
  if k.blame_file then
    map("n", k.blame_file, function() require("baka.blame").file() end,
      { desc = "Baka git blame file (toggle)" })
  end
  if k.history then
    map("n", k.history, function() require("baka.history").show() end,
      { desc = "Baka git history" })
    map("v", k.history, function()
      local s = vim.fn.getpos("v")[2]
      local e = vim.fn.getpos(".")[2]
      if s > e then s, e = e, s end
      vim.cmd("normal! \27")
      require("baka.history").show({ range = { s, e } })
    end, { desc = "Baka git history (range)" })
  end
  if k.remote then
    map({ "n", "v" }, k.remote, function() require("baka.remote").open() end,
      { desc = "Baka git open in remote" })
  end
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  M.config = opts
  require("baka.highlights").setup()
  require("baka.remote").setup(opts.remote)
  set_keymaps(opts.keymaps)
end

-- Public API (call directly if you don't want the default keymaps).
M.blame_line  = function() require("baka.blame").line() end
M.blame_file  = function() require("baka.blame").file() end
M.history     = function(opts) require("baka.history").show(opts) end
M.show_commit = function(sha, file, cwd) require("baka.history").show_commit(sha, file, cwd) end
M.remote      = function() require("baka.remote").open() end

return M
