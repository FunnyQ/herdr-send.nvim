local config = require("herdr-send.config")
local pick = require("herdr-send.ui.picker")

local M = {}

function M.send()
  pick(nil)
end

function M.send_selection()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  pick({ rel = vim.fn.expand("%:."), abs = vim.fn.expand("%:p"), a = a, b = b })
end

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})
end

return M
