local config = require("herdr-send.config")
local pick = require("herdr-send.ui.picker")

local M = {}

function M.send()
  pick(nil)
end

function M.send_selection()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  pick({ rel = vim.fn.expand("%:."), abs = vim.fn.expand("%:p"), a = a, b = b })
end

function M.setup(opts)
  opts = opts or {}
  config.options = vim.tbl_deep_extend("force", config.options, opts)
  -- older Neovim merges list tables by index in tbl_deep_extend; a user key list must replace the default whole
  config.options.send_key = opts.send_key or config.options.send_key
end

return M
