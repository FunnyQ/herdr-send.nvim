local M = {}

M.options = {
  send_key = "<C-s>",
  chip = {
    local_hl = "DiffAdd",
    remote_hl = "DiffChange",
    last_hl = "Search",
    tab_hl = "TabLine",
    tab_active_hl = "TabLineSel",
  },
  split_machines = false,
  filter = nil,
}

return M
