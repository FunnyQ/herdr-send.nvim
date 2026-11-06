local M = {}

M.options = {
  send_key = { "<C-s>", "<D-CR>" },
  back_key = "<BS>",
  close_key = "<C-q>",
  zoom_key = "<C-CR>",
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
}

return M
