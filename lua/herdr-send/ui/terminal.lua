local config = require("herdr-send.config")

return function(item)
  local close_key, zoom_key = config.options.close_key, config.options.zoom_key
  local buf = vim.api.nvim_create_buf(false, true)
  local zoomed = false
  local function geometry()
    local width = zoomed and vim.o.columns - 2 or math.min(80, vim.o.columns - 2)
    return {
      relative = "editor",
      width = width, height = vim.o.lines - vim.o.cmdheight - 2,
      row = 0, col = vim.o.columns - width - 2,
    }
  end
  local win = vim.api.nvim_open_win(buf, true, vim.tbl_extend("force", geometry(), {
    border = "rounded",
    title = (" %s · %s (%s) "):format(item.agent, item.tab, item.t.address), title_pos = "center",
    footer = (" %s detach · %s zoom "):format(close_key, zoom_key), footer_pos = "center",
  }))
  vim.fn.jobstart({ "hc", "attach", item.t.address }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
  vim.keymap.set({ "n", "t" }, close_key, function() vim.api.nvim_buf_delete(buf, { force = true }) end, { buffer = buf })
  vim.keymap.set({ "n", "t" }, zoom_key, function()
    zoomed = not zoomed
    vim.api.nvim_win_set_config(win, geometry())
  end, { buffer = buf })
  vim.cmd.startinsert()
end
