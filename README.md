# herdr-send.nvim

Send a file or line-range reference from Neovim to a coding agent running in herdr-app, with a message you write in a floating buffer.

The picker groups agents by herdr-app space, on this machine and on remote `hc` machines. The title shows one tab per space, with the space Neovim runs in first.

## Requirements

- Neovim 0.11 or later
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
    { "<D-CR>", function() require("herdr-send").send() end, desc = "Send message to agent" },
    { "<D-CR>", function() require("herdr-send").send_selection() end, mode = "v", desc = "Send selection to agent" },
    { "<leader>at", function() require("herdr-send").attach() end, desc = "Attach to agent" },
  },
}
```

The plugin binds no global keys. Bind `send`, `send_selection`, and `attach` yourself.

## Usage

1. Press your key in normal mode to write a plain message, or in visual mode to start it with `@path#Lstart-end`. A selection inside one line starts it with `@path`.
2. Press `h`/`l` or `<Left>`/`<Right>` to switch space. Pick an agent with `j`/`k` and `<CR>`. The agent you last sent to sits at the top of its space and carries a `last sent` chip. Press `i` to search. Each row shows the agent, its `model/effort`, tab, status, machine, and terminal id. The preview shows the agent's current screen. When the space Neovim runs in holds exactly one agent, the picker is skipped and step 3 opens directly.
3. Write the message. From visual mode, the first line holds the reference: a cwd-relative path for a local agent in the current space, an absolute path for any other agent. Edit or delete it as needed.
4. Press a `send_key` to send, or `close_key` to cancel. Press `back_key` in normal mode to return to the picker with the message kept. When the first line is still the untouched reference, it is rewritten for the agent you pick next.

### New agent

When the space Neovim runs in holds no agent, its tab still comes first and lists one `＋ New <name>` row per installed harness in `new_agents`. Pick a row to start that harness in a new terminal under Neovim and open it in the attach window. From visual mode, the reference is not carried over; send it once the agent is ready. The new agent ends when the herdr-app terminal Neovim runs in closes.

### Attach

Call `attach` to pick an agent the same way and open its terminal in a floating window through `hc attach`. Type into the agent directly. Press `zoom_key` to toggle between the right-side window and the full editor width. Press `close_key` to close the window. Closing the window detaches; the agent keeps running in its herdr-app pane.

`hc send` pastes the text and presses Enter, so the agent starts its turn at once.

## Options

```lua
{
  send_key = { "<C-s>", "<D-CR>" },                        -- key or list of keys that send from the message window; the footer shows the first
  back_key = "<BS>",                                       -- normal mode: returns from the message window to the picker
  close_key = "<C-q>",                                     -- closes the message window and the attach window; the agent never receives this key
  zoom_key = "<C-CR>",                                     -- toggles the attach window to full editor width; the agent never receives this key
  chip = {                       -- highlight groups whose background colors each chip
    local_hl = "DiffAdd",          -- machine chip, this machine
    remote_hl = "DiffChange",      -- machine chip, remote machine
    last_hl = "Search",            -- `last sent` chip on the agent you last sent to
    tab_hl = "TabLine",            -- space tab
    tab_active_hl = "TabLineSel",  -- selected space tab
  },
  new_agents = {                                           -- harnesses offered in an empty current space; a harness whose command is not on PATH is hidden
    { name = "claude", cmd = { "claude" } },
    { name = "codex", cmd = { "codex" } },
    { name = "opencode", cmd = { "opencode" } },
  },
  split_machines = false,                                  -- true: a remote space gets its own `space@machine` tab
  filter = nil,                                            -- function(terminal) -> boolean, extra filter on `hc ls --json` entries
}
```

## Test

```sh
nvim -l tests/run.lua
```
