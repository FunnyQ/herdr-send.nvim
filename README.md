# herdr-send.nvim

Send a file or line-range reference from Neovim to a coding agent running in herdr-app, with a message you write in a floating buffer.

The picker groups agents by herdr-app space, on this machine and on remote `hc` machines. The title shows one tab per space, with the space Neovim runs in first.

## Requirements

- Neovim 0.11 or later
- `hc` (herdr-core) on `PATH`, and Neovim running inside a herdr-app terminal
- [snacks.nvim](https://github.com/folke/snacks.nvim) with the picker enabled
- A Nerd Font, for the machine chip edges and the rounded window labels

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
3. Write the message in the window at the bottom left. When the attach window is open and not zoomed, the message window narrows to stay clear of it, unless that leaves under 40 columns. From visual mode, the first line holds the reference: a cwd-relative path for a local agent in the current space, an absolute path for any other agent. Edit or delete it as needed.
4. Press a `send_key` to send, or `close_key` to cancel. Press `back_key` in normal mode to return to the picker with the message kept. When the first line is still the untouched reference, it is rewritten for the agent you pick next.

### New agent

When the space Neovim runs in holds no agent, its tab still comes first and lists one `＋ New <name>` row per installed harness in `new_agents`. Pick a row to start that harness in a new terminal under Neovim and open it in the attach window. From visual mode, the reference is not carried over; send it once the agent is ready. The new agent ends when the herdr-app terminal Neovim runs in closes.

### Attach

Call `attach` to pick an agent the same way and open its terminal in a floating window through `hc attach`. Type into the agent directly. Press `toggle_key` once to hide the window; the attach keeps running. Call `attach` again to show the hidden window without the picker. Press `toggle_key` twice within `double_tap_ms` to toggle between the right-side window and the full editor width. Press `close_key` to close the window. Closing the window detaches; the agent keeps running in its herdr-app pane, and the next `attach` opens the picker.

Bind `attach` to the same key as `toggle_key` to show and hide the window with one key.

`hc send` pastes the text and presses Enter, so the agent starts its turn at once.

### Statusline

Call `status()` for a short string with the state of the relevant agent, such as `● working` or `● idle`, or `""` when there is none. Call `status_hl()` for the matching highlight group, or `nil`.

The relevant agent is the agent you last sent to when it sits in the space Neovim runs in. Otherwise it is the only agent of that space. Outside herdr-app, it is the agent you last sent to.

The first `status()` call starts one `hc events` stream in the background. Each call after that reads a cached value, so the statusline never waits on `hc`. When the stream ends, it reconnects after 5 seconds.

```lua
-- lualine
{
  function() return require("herdr-send").status() end,
  color = function() return require("herdr-send").status_hl() end,
}
```

### Reply notifications

When the relevant agent goes from `working` to `done`, herdr-send calls `vim.notify` with the reply, titled `<agent> done`. A permission prompt (`blocked`) does not count as done.

The notification stays open until you act outside it. Focusing it, typing in it, and scrolling over it do not count. The key that leaves it counts. After the first other key or mouse action, it closes `notify_linger_ms` later. It stays open while it has focus. While the picker or the message window of `send` is open, keys do not count, and a countdown already running stops.

With nvim-notify's default render, the header ends with `[X]` after the time. Click it to close the notification at once. To close it from a key, map `require("notify").dismiss({ silent = true, pending = true })`, which closes every notification.

For a local Claude Code agent, the body is the text of the last assistant message in its transcript under `~/.claude/projects/`, in full. The notification window gets filetype `markdown` and `wrap`, so treesitter and render-markdown.nvim render it like a buffer. The body is pre-wrapped to nvim-notify's `max_width` at spaces and between CJK characters, without splitting inline code or bold. For other harnesses and remote agents, the body is `done`.

When `setup` runs inside herdr-app, it starts the `hc events` stream, so notifications work without the statusline. Set `notify_on_done = false` to turn them off.

Set `notify` to pass extra `vim.notify` opts to the reply notification only. Its keys override the defaults, `title` included. A `timeout` or `keep` here replaces the `notify_linger_ms` behavior. If you set `on_open`, it runs after the window gets filetype `markdown`, never instead of it. With `render = "compact"`, the body starts on the line below the title, so every line stays inside `max_width`.

## Options

```lua
{
  send_key = { "<C-s>", "<D-CR>" },                        -- key or list of keys that send from the message window; the footer shows the first
  back_key = "<BS>",                                       -- normal mode: returns from the message window to the picker
  close_key = "<C-q>",                                     -- closes the message window and the attach window; the agent never receives this key
  toggle_key = "<C-CR>",                                   -- once hides the attach window, twice within `double_tap_ms` toggles full editor width; the agent never receives this key
  double_tap_ms = 190,                                     -- max milliseconds between two `toggle_key` presses to zoom; a single press hides after this delay
  winblend = 8,                                            -- 0-100, pseudo-transparency of the message and attach windows; blends with the text beneath
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
  notify_on_done = true,                                   -- vim.notify the reply when the relevant agent finishes a turn
  notify_linger_ms = 3000,                                 -- after your first action outside the reply notification, close it this many milliseconds later
  notify = {},                                             -- extra vim.notify opts for the reply notification, e.g. { render = "compact" }
}
```

## Test

```sh
nvim -l tests/run.lua
```
