local config = require("herdr-send.config")

local M = {}
local state

local function geometry()
  local width = state.zoomed and vim.o.columns - 2 or math.min(80, vim.o.columns - 2)
  return {
    relative = "editor",
    width = width, height = vim.o.lines - vim.o.cmdheight - 2,
    row = 0, col = vim.o.columns - width - 2,
  }
end

local function open_win()
  local item = state.item
  state.win = vim.api.nvim_open_win(state.buf, true, vim.tbl_extend("force", geometry(), {
    border = "rounded",
    title = (" %s · %s (%s) "):format(item.agent, item.tab, item.t.address), title_pos = "center",
    footer = (" %s detach · %s hide · %s×2 zoom "):format(config.options.close_key, config.options.toggle_key,
      config.options.toggle_key), footer_pos = "center",
  }))
  vim.cmd.startinsert()
end

function M.reserved()
  if not (state and vim.api.nvim_win_is_valid(state.win)) or state.zoomed then return 0 end
  return vim.api.nvim_win_get_width(state.win) + 2
end

function M.show()
  if not (state and vim.api.nvim_buf_is_valid(state.buf)) then return false end
  if vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    vim.cmd.startinsert()
  else
    open_win()
  end
  return true
end

function M.open(item)
  if state and vim.api.nvim_buf_is_valid(state.buf) then vim.api.nvim_buf_delete(state.buf, { force = true }) end
  local buf = vim.api.nvim_create_buf(false, true)
  local s = { buf = buf, item = item, zoomed = false }
  state = s
  open_win()
  vim.fn.jobstart({ "hc", "attach", item.t.address }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
  vim.keymap.set({ "n", "t" }, config.options.close_key, function() vim.api.nvim_buf_delete(buf, { force = true }) end, { buffer = buf })
  local pending
  vim.keymap.set({ "n", "t" }, config.options.toggle_key, function()
    if pending then
      pending:close()
      pending = nil
      s.zoomed = not s.zoomed
      vim.api.nvim_win_set_config(s.win, geometry())
      return
    end
    pending = vim.defer_fn(function()
      pending = nil
      if vim.api.nvim_win_is_valid(s.win) then vim.api.nvim_win_close(s.win, false) end
    end, config.options.double_tap_ms)
  end, { buffer = buf })
end

return M
