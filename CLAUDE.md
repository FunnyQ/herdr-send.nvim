# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Neovim plugin that sends a message (optionally starting with an `@path#Lstart-end` reference) to a coding agent running in a herdr-app terminal, via the `hc` CLI. See README.md for user-facing behavior and options.

## Commands

- Run tests: `nvim -l tests/run.lua` (run from the repo root; it prepends `lua/` to `package.path`).
- No single-test runner exists. Tests are `eq(name, got, want)` calls in `tests/run.lua`; comment out others or add a new `eq` to isolate one. The script exits non-zero on any failure.
- No build or lint step.

## Architecture

Modules under `lua/herdr-send/`:

- `init.lua`: public API only (`send`, `send_selection`, `attach`, `status`, `status_hl`, `setup`).
- `status.lua`: on the first `status()` call, follows `hc events --json` (one snapshot line, then JSON-RPC `event` lines whose `data` merges into the terminal) and caches the statusline text. `status()` never runs `hc`. A `working` -> `done` change of the status target calls `notify`.
- `notify.lua`: resolves `hc get` pid -> `~/.claude/sessions/<pid>.json` (walking child pids, then newest `.jsonl` of the cwd project) -> transcript, polls until its `turn_duration` line (Claude Code flushes the reply after hc reports done), all async in a coroutine, then `vim.notify`s the last reply.
- `config.lua`: defaults in `options`. `setup` replaces `options`, so read `require("herdr-send.config").options` at call time, never cache it at module load.
- `core.lua`: pure functions (`parse`, `is_agent`, `group_spaces`, `only_agent`, `same_space`, `ref_for`, `ref`, `last_first`, `initial_lines`, `retarget`, `with_new_agents`, `keys`, `compose_size`, `model_label`, `split_lines`, `ls_view`, `apply_event`, `status_target`, `status_text`, `finished`, `project_slug`, `last_reply`, `turn_ended`, `truncate`). Put new logic here when it can be tested without Neovim UI or `hc`.
- `ui/render.lua`: picker visuals. `chip` and `tab_chunks` are pure and tested; `set_chip_hl` and `draw_tabs` touch highlights and windows.
- `hc.lua`: `run` wraps the `hc` CLI; `read_last` / `write_last` persist the last-sent address.
- `ui/picker.lua`: calls `hc get $HC_TERMINAL_ID --json` to find the current space and `hc ls --json` to list terminals, then builds a snacks.nvim picker with one tab per space.
- `ui/compose.lua`: opens a floating markdown buffer and sends with `hc send <address> -- <text>`.
- `ui/terminal.lua`: opens a floating terminal running `hc attach <address>`; deleting the buffer ends the job, which detaches.

`tests/run.lua` covers `core` and `ui/render`.

Data model from `hc ls --json`:

- `address` is `t<id>` locally or `<machine>/t<id>` for remote machines.
- `labels.where` / `where` is `"<space> / <icon> <tab>"`; `parse` splits it.
- A terminal counts as an agent only when it has a `status`, has a `where`, and is not Neovim's own `HC_TERMINAL_ID` (`is_agent`).

The last-sent address is persisted as a single line in `stdpath("state")/herdr-send-last` and floated to the top of its space by `last_first`.

The reference uses a cwd-relative path when the target agent is local and in Neovim's current space, an absolute path otherwise (`same_space`, `ref_for`). Spaces group by name across machines unless `split_machines` is set.
