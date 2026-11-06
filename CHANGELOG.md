# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-07

_tracks tag `v0.3.0`_

### Added
- The picker offers "New <agent>" rows when your Neovim space has no agent running, starting the chosen agent in a login shell and opening its terminal; configure the list with `new_agents`.
- `attach()` lets you pick an agent and operate it in a floating terminal; closing the window detaches while the agent keeps running, and `zoom_key` toggles full width.
- A `close_key` option (default `<C-q>`) cancels the compose window from normal and insert mode, and the window is now a 4:3 landscape up to 80 columns that wraps without splitting words.

### Changed
- Neovim 0.11 or newer is now required, because the attach terminal depends on it.

## [0.2.1] - 2026-11-06

_tracks tag `v0.2.1`_

### Added
- A selection within a single line now sends a bare `@path` file reference instead of one with a line range, so you can reference just the file from a line you are on.

### Fixed
- Sending from visual mode no longer drops the compose window into normal mode when the lone-agent picker skip opens it immediately.

## [0.2.0] - 2026-11-06

_tracks tag `v0.2.0`_

### Added
- `send_key` now accepts a single key or a list, and Cmd-Return (`<D-CR>`) sends the message on macOS alongside the existing `<C-s>`.
- The picker is skipped when the current space holds exactly one agent, and a new `back_key` (default `<BS>`) returns from the message window to the picker with your draft kept.

## [0.1.1] - 2026-11-06

_tracks tag `v0.1.1`_

### Fixed
- The agent preview window no longer wraps long lines or shows an empty gutter on the left, so the terminal snapshot renders like the agent's own pane.

## [0.1.0] - 2026-11-06

_tracks tag `v0.1.0`_

### Added
- Send a file or line-range reference plus a message from a floating buffer to a coding agent in herdr-app, picking the target from a snacks.nvim picker with one tab per space across local and remote machines.
- Documented requirements, installation, usage and options in a new README, and released the plugin under the MIT license.
- Added a `split_machines` option (off by default) that gives remote spaces their own `space@machine` tab.

### Fixed
- Tab names with CJK or accented characters are no longer mangled, since only Nerd Font icon codepoints are stripped, and the raw agent name is kept instead of a shortened claude-code.
- Model labels are no longer misdetected from values like `X=--model foo`, and remote agents now get absolute paths while only local agents in the current space get cwd-relative ones.
