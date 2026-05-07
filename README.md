# baka.nvim

A small, dependency-free git overlay for Neovim. Blame, history, and
remote-open — in floating popups that inherit your colorscheme.

## Features

- **`<leader>bb`** — Baka git blame line. Cursor-anchored popup with
  sha, author, date, and commit summary. Auto-closes on movement.
- **`<leader>bB`** — Baka git blame file. Toggles a left-side,
  scroll-bound full-file blame split. Press `<CR>` on a row to view
  that commit's diff. Same key closes it.
- **`<leader>bh`** — Baka git history. Centered popup showing commits
  that touch the current file, with the active branch in the title
  (`history file.lua [main]`). Scroll near the bottom to lazy-load older
  commits — 20 at a time, up to 100 total. In visual mode, scopes to
  the selected line range (`git log -L`).
- **`<leader>bo`** — Baka git open in remote. Opens the current line
  (or visual range) in the browser on GitHub or GitLab. Resolves SSH
  host aliases from `~/.ssh/config`, so SSO setups work.
- **`<leader>bd`** — Baka git diff vs master. Side-by-side native diff
  against `master` (fallback `main` / `origin/master` / `origin/main`).
  Opaque, theme-aligned line backgrounds — no `+`/`-` markers. The base
  side auto-refreshes when you navigate to another file in the head
  window. `]c` / `[c` jump hunks; `do` / `dp` transfer; `q` or `<leader>bd`
  again closes.
- **`<leader>bc`** — Baka git changes vs master. PR walker: builds a
  quickfix list of every file changed since the merge-base with master
  (committed, staged, unstaged), opens diff on the first one. Walk the
  list with `]q` / `[q` — each jump auto-refreshes the base side.

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
    blame_line = "<leader>bb",
    blame_file = "<leader>bB",
    history    = "<leader>bh",
    remote     = "<leader>bo",
    diff       = "<leader>bd",
    changes    = "<leader>bc",
  },
  remote = {
    -- SSH host aliases -> real hostnames. Auto-resolved from ~/.ssh/config;
    -- entries here take precedence. Useful for enterprise SSO setups.
    host_map = {
      -- ["github-work"] = "github.com",
    },
  },
  history = {
    page_size = 20,  -- commits loaded initially, and per scroll-page
    max       = 100, -- hard cap on total commits the popup will fetch
  },
})
```

Set any keymap to `false` to disable it. The equivalent commands are
always available:

```
:Baka line          -- blame current line popup
:Baka blame         -- full-file blame split (toggle)
:Baka history       -- file history popup (also accepts a :range)
:'<,'>Baka history  -- range-scoped history (git log -L)
:Baka remote        -- open in browser
:Baka diff [ref]    -- side-by-side diff vs ref (default: master / main)
:Baka changes [ref] -- qflist of changed files vs ref + open diff on first
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
| `BakaDiffNormal`   | `Normal`      |
| `BakaDiffAdd`      | `DiffAdd`     |
| `BakaDiffDelete`   | `DiffDelete`  |
| `BakaDiffChange`   | `DiffChange`  |
| `BakaDiffText`     | `DiffText`    |

The `BakaDiff*` groups are applied via `winhighlight` only inside the
diff windows, so global `Diff*` usage by other plugins is unaffected.
Override `BakaDiffNormal` with a real `bg` if your colorscheme uses
transparent backgrounds — that's what makes the diff windows opaque
without touching the rest of the editor.

Override any of them after `setup()`:

```lua
vim.api.nvim_set_hl(0, "BakaBorder", { fg = "#78a9ff" })
vim.api.nvim_set_hl(0, "BakaSha",    { fg = "#f5a97f", bold = true })
```

## Why `baka`?

Linus Torvalds named *git* after a British insult — "an unpleasant
person". *Baka* (馬鹿) is the closest Japanese equivalent: idiot, fool.
Same joke, different language.

## License

[MIT](./LICENSE).
