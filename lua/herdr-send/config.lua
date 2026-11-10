local M = {}

M.options = {
  send_key = { "<C-s>", "<D-CR>" },
  back_key = "<BS>",
  close_key = "<C-q>",
  toggle_key = "<C-CR>",
  double_tap_ms = 190,
  winblend = 8,
  chip = {
    local_hl = "DiffAdd",
    remote_hl = "DiffChange",
    last_hl = "Search",
    tab_hl = "TabLine",
    tab_active_hl = "TabLineSel",
  },
  new_agents = {
    { name = "claude", cmd = { "claude" } },
    { name = "codex", cmd = { "codex" } },
    { name = "opencode", cmd = { "opencode" } },
  },
  split_machines = false,
  filter = nil,
  notify_on_done = true,
  notify_linger_ms = 3000,
  notify_max = 3,
  notify_max_age_ms = 8 * 60 * 1000,
  notify = {},
}

return M
