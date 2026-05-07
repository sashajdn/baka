-- baka.nvim — small, dependency-free git overlay for Neovim.
local M = {}

local defaults = {
  keymaps = {
    blame_line = "<leader>gb",
    blame_file = "<leader>gB",
    history    = "<leader>gH",
    remote     = "<leader>gg",
  },
}

M.config = defaults

local function set_keymaps(k)
  local map = vim.keymap.set
  if k.blame_line then
    map("n", k.blame_line, function() require("baka.blame").line() end,
      { desc = "baka: blame line" })
  end
  if k.blame_file then
    map("n", k.blame_file, function() require("baka.blame").file() end,
      { desc = "baka: blame file" })
  end
  if k.history then
    map("n", k.history, function() require("baka.history").show() end,
      { desc = "baka: file history" })
    map("v", k.history, function()
      local s = vim.fn.getpos("v")[2]
      local e = vim.fn.getpos(".")[2]
      if s > e then s, e = e, s end
      vim.cmd("normal! \27")
      require("baka.history").show({ range = { s, e } })
    end, { desc = "baka: range history" })
  end
  if k.remote then
    map({ "n", "v" }, k.remote, function() require("baka.remote").open() end,
      { desc = "baka: open in remote" })
  end
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})
  M.config = opts
  require("baka.highlights").setup()
  set_keymaps(opts.keymaps)
end

-- Public API (call directly if you don't want the default keymaps).
M.blame_line  = function() require("baka.blame").line() end
M.blame_file  = function() require("baka.blame").file() end
M.history     = function(opts) require("baka.history").show(opts) end
M.show_commit = function(sha, file, cwd) require("baka.history").show_commit(sha, file, cwd) end
M.remote      = function() require("baka.remote").open() end

return M
