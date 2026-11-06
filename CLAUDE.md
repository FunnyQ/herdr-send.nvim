# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Neovim plugin that sends a message (optionally starting with an `@path#Lstart-end` reference) to a coding agent running in a herdr-app terminal, via the `hc` CLI. See README.md for user-facing behavior and options.

## Commands

- Run tests: `nvim -l tests/run.lua` (run from the repo root; it prepends `lua/` to `package.path`).
- No single-test runner exists. Tests are `eq(name, got, want)` calls in `tests/run.lua`; comment out others or add a new `eq` to isolate one. The script exits non-zero on any failure.
- No build or lint step.

## Architecture

All code is in `lua/herdr-send/init.lua`, split into two layers:

- **Pure functions exported on `M`** (`parse`, `is_agent`, `group_spaces`, `ref_for`, `ref`, `last_first`, `initial_lines`, `model_label`, `chip`, `tab_chunks`). These take plain tables/strings and are what `tests/run.lua` covers. Put new logic here when it can be tested without Neovim UI or `hc`.
- **UI and side effects** (`M.pick`, `compose`, `draw_tabs`, `set_chip_hl`): `M.pick` calls `hc get $HC_TERMINAL_ID --json` to find the current space and `hc ls --json` to list terminals, then builds a snacks.nvim picker with one tab per space. `compose` opens a floating markdown buffer and sends with `hc send <address> -- <text>`.

Data model from `hc ls --json`:

- `address` is `t<id>` locally or `<machine>/t<id>` for remote machines.
- `labels.where` / `where` is `"<space> / <icon> <tab>"`; `parse` splits it.
- A terminal counts as an agent only when it has a `status`, has a `where`, and is not Neovim's own `HC_TERMINAL_ID` (`is_agent`).

The last-sent address is persisted as a single line in `stdpath("state")/herdr-send-last` and floated to the top of its space by `last_first`.

The reference uses a cwd-relative path when the target agent is in Neovim's current space, an absolute path otherwise (`ref_for`).
