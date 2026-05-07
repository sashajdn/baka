# baka.nvim

A small, dependency-free git overlay for Neovim. Blame, history, and
remote-open — in floating popups that inherit your colorscheme.

## Features

- **`<leader>gb`** — blame the current line in a cursor-anchored popup
  (sha, author, date, summary). Auto-closes on movement.
- **`<leader>gB`** — full-file blame in a left-side, scroll-bound split.
  Press `<CR>` on a line to view that commit's diff.
- **`<leader>gH`** — last 20 commits touching the current file in a
  centered popup. In visual mode, scopes to the selected line range
  (`git log -L`).
- **`<leader>gg`** — open the current line (or visual range) in the
  browser on GitHub or GitLab.

`q` or `<Esc>` closes any popup.

## Requirements

- Neovim **0.10+** (uses `vim.system`).
- `git` on `$PATH`.
- No plugin dependencies.

## Install

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{ "sashajdn/baka", config = true }
```

For local development, point at a checkout:

```lua
{ dir = "~/repos/baka", config = true }
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "sashajdn/baka",
  config = function() require("baka").setup() end,
}
```

### [pckr.nvim](https://github.com/lewis6991/pckr.nvim)

```lua
require("pckr").add({
  { "sashajdn/baka", config = function() require("baka").setup() end },
})
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'sashajdn/baka'
```

Then in your Lua config:

```lua
require("baka").setup()
```

### [mini.deps](https://github.com/echasnovski/mini.deps)

```lua
MiniDeps.add("sashajdn/baka")
require("baka").setup()
```

### Manual (no plugin manager)

```sh
git clone https://github.com/sashajdn/baka \
  ~/.local/share/nvim/site/pack/baka/start/baka
```

Then in `init.lua`:

```lua
require("baka").setup()
```

## Configure

Defaults shown:

```lua
require("baka").setup({
  keymaps = {
    blame_line = "<leader>gb",
    blame_file = "<leader>gB",
    history    = "<leader>gH",
    remote     = "<leader>gg",
  },
})
```

Set any keymap to `false` to disable it. The equivalent commands are
always available:

```
:Baka line          -- blame current line popup
:Baka blame         -- full-file blame split
:Baka history       -- file history popup (also accepts a :range)
:'<,'>Baka history  -- range-scoped history (git log -L)
:Baka remote        -- open in browser
```

## Theming

All visible elements use `Baka*` highlight groups, linked by default to
standard groups so any colorscheme works out of the box:

| Group              | Default link  |
| ------------------ | ------------- |
| `BakaSha`          | `Identifier`  |
| `BakaAuthor`       | `String`      |
| `BakaDate`         | `Comment`     |
| `BakaSubject`      | `Normal`      |
| `BakaUncommitted`  | `WarningMsg`  |
| `BakaHint`         | `Comment`     |
| `BakaNormal`       | `NormalFloat` |
| `BakaBorder`       | `FloatBorder` |
| `BakaTitle`        | `FloatTitle`  |

Override any of them after `setup()`:

```lua
vim.api.nvim_set_hl(0, "BakaSha", { fg = "#f5a97f", bold = true })
```

## Why `baka`?

Linus Torvalds named *git* after a British insult — "an unpleasant
person". *Baka* (馬鹿) is the closest Japanese equivalent: idiot, fool.
Same joke, different language.

## License

[MIT](./LICENSE).
