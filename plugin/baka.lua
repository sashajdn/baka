-- plugin/baka.lua — auto-loaded entrypoint. Registers :Baka, but does not
-- install keymaps or highlights until the user calls require("baka").setup().
if vim.g.loaded_baka then return end
vim.g.loaded_baka = 1

vim.api.nvim_create_user_command("Baka", function(opts)
  local sub = opts.fargs[1]
  if sub == "blame" then
    require("baka.blame").file()
  elseif sub == "line" then
    require("baka.blame").line()
  elseif sub == "history" then
    if opts.range > 0 then
      require("baka.history").show({ range = { opts.line1, opts.line2 } })
    else
      require("baka.history").show()
    end
  elseif sub == "remote" then
    require("baka.remote").open()
  else
    vim.notify("Baka: subcommands: blame | line | history | remote", vim.log.levels.INFO)
  end
end, {
  nargs = 1,
  range = true,
  complete = function() return { "blame", "line", "history", "remote" } end,
  desc = "baka.nvim: blame | line | history | remote",
})
