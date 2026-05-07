-- baka.highlights: define Baka* groups linked to standard highlight groups
-- so they inherit the user's colorscheme automatically. All groups are
-- created with `default = true` so user overrides take precedence.
local M = {}

M.ns = vim.api.nvim_create_namespace("baka")

local links = {
  -- Field-level (used inside blame/log row buffers)
  BakaSha         = "Identifier",
  BakaAuthor      = "String",
  BakaDate        = "Comment",
  BakaSubject     = "Normal",
  BakaUncommitted = "WarningMsg",
  BakaHint        = "Comment",

  -- Float chrome
  BakaNormal      = "NormalFloat",
  BakaBorder      = "FloatBorder",
  BakaTitle       = "FloatTitle",
}

function M.apply()
  for name, target in pairs(links) do
    vim.api.nvim_set_hl(0, name, { link = target, default = true })
  end
end

function M.setup()
  M.apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("BakaHighlights", { clear = true }),
    callback = M.apply,
  })
end

-- Window-local highlight string for floats. Apply with vim.wo[win].winhl = M.float_winhl.
M.float_winhl = "Normal:BakaNormal,FloatBorder:BakaBorder,FloatTitle:BakaTitle,CursorLine:CursorLine"

return M
