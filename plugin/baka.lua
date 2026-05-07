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
  elseif sub == "diff" then
    require("baka.diff").toggle(opts.fargs[2])
  elseif sub == "changes" then
    require("baka.diff").changes(opts.fargs[2])
  else
    vim.notify("Baka: subcommands: blame | line | history | remote | diff [ref] | changes [ref]", vim.log.levels.INFO)
  end
end, {
  nargs = "+",
  range = true,
  complete = function(arglead, cmdline)
    if cmdline:match("^Baka%s+%S*$") then
      return { "blame", "line", "history", "remote", "diff", "changes" }
    end
    return {}
  end,
  desc = "baka.nvim: blame | line | history | remote | diff | changes",
})
