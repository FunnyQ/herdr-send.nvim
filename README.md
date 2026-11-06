# herdr-send.nvim

Send a file or line-range reference from Neovim to a coding agent running in herdr-app, with a message you write in a floating buffer.

The picker groups agents by herdr-app space, on this machine and on remote `hc` machines. The title shows one tab per space, with the space Neovim runs in first.

## Requirements

- Neovim 0.10 or later
- `hc` (herdr-core) on `PATH`, and Neovim running inside a herdr-app terminal
- [snacks.nvim](https://github.com/folke/snacks.nvim) with the picker enabled
- A Nerd Font, for the machine chip edges

## Install

```lua
{
  "FunnyQ/herdr-send.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {},
  keys = {
    { "<C-s>", function() require("herdr-send").send() end, desc = "Send message to agent" },
    { "<C-s>", function() require("herdr-send").send_selection() end, mode = "v", desc = "Send selection to agent" },
  },
}
```

The plugin binds no global keys. Bind `send` and `send_selection` yourself.

## Usage

1. Press your key in normal mode to write a plain message, or in visual mode to start it with `@path#Lstart-end`.
2. Press `h`/`l` or `<Left>`/`<Right>` to switch space. Pick an agent with `j`/`k` and `<CR>`. The agent you last sent to sits at the top of its space and carries a `last sent` chip. Press `i` to search. Each row shows the agent, its `model/effort`, tab, status, machine, and terminal id. The preview shows the agent's current screen.
3. Write the message. From visual mode, the first line holds the reference: a cwd-relative path for a local agent in the current space, an absolute path for any other agent. Edit or delete it as needed.
4. Press `send_key` to send, or `q` in normal mode to cancel.

`hc send` pastes the text and presses Enter, so the agent starts its turn at once.

## Options

```lua
{
  send_key = "<C-s>",                                      -- sends from the message window
  chip = {                       -- highlight groups whose background colors each chip
    local_hl = "DiffAdd",          -- machine chip, this machine
    remote_hl = "DiffChange",      -- machine chip, remote machine
    last_hl = "Search",            -- `last sent` chip on the agent you last sent to
    tab_hl = "TabLine",            -- space tab
    tab_active_hl = "TabLineSel",  -- selected space tab
  },
  split_machines = false,                                  -- true: a remote space gets its own `space@machine` tab
  filter = nil,                                            -- function(terminal) -> boolean, extra filter on `hc ls --json` entries
}
```

## Test

```sh
nvim -l tests/run.lua
```
