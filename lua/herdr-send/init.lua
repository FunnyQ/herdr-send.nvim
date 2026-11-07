local config = require("herdr-send.config")
local pick = require("herdr-send.ui.picker")
local terminal = require("herdr-send.ui.terminal")
local status = require("herdr-send.status")

local M = {}

function M.send()
  pick(nil)
end

function M.send_selection()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  pick({ rel = vim.fn.expand("%:."), abs = vim.fn.expand("%:p"), a = a, b = b })
end

function M.attach()
  if not terminal.show() then pick(nil, nil, terminal.open) end
end

M.status = status.text
M.status_hl = status.hl

function M.setup(opts)
  opts = opts or {}
  config.options = vim.tbl_deep_extend("force", config.options, opts)
  -- older Neovim merges list tables by index in tbl_deep_extend; a user key list must replace the default whole
  config.options.send_key = opts.send_key or config.options.send_key
  config.options.new_agents = opts.new_agents or config.options.new_agents
  if config.options.notify_on_done and vim.env.HC_TERMINAL_ID then status.start() end
end

return M
