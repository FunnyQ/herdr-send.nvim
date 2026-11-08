local config = require("herdr-send.config")
local core = require("herdr-send.core")
local hc = require("herdr-send.hc")
local render = require("herdr-send.ui.render")
local terminal = require("herdr-send.ui.terminal")

return function(item, lines, back)
  local send_keys, back_key, close_key = core.keys(config.options.send_key), config.options.back_key, config.options.close_key
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local corner = vim.fn.getwininfo(vim.api.nvim_win_call(vim.fn.win_getid(vim.fn.winnr("1000h")),
    function() return vim.fn.win_getid(vim.fn.winnr("1000j")) end))[1]
  local rect = core.compose_rect(vim.o.columns, vim.o.lines, vim.o.cmdheight, terminal.reserved(),
    corner.textoff, vim.o.lines - vim.o.cmdheight - corner.winrow - corner.height + 1)
  render.set_pill_hl("FloatTitle")
  render.set_pill_hl("FloatFooter")
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    width = rect.width, height = rect.height, row = rect.row, col = rect.col,
    title = render.pill(("→ %s · %s"):format(item.agent, item.tab), "FloatTitle"), title_pos = "center",
    footer = render.pill(("%s send · %s agents · %s cancel"):format(send_keys[1], back_key, close_key), "FloatFooter"),
    footer_pos = "center",
  })
  vim.w[win].herdr_send_busy = true
  vim.wo[win].winblend = config.options.winblend
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  vim.cmd.startinsert()
  local function send()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    vim.cmd.stopinsert()
    vim.api.nvim_win_close(win, true)
    if text == "" then
      vim.notify("Empty message, nothing sent", vim.log.levels.WARN)
      return
    end
    local out = hc.run({ "send", item.t.address, "--", text })
    if vim.v.shell_error ~= 0 then
      vim.notify("hc send failed: " .. out, vim.log.levels.ERROR)
      return
    end
    hc.write_last(item.t.address)
    vim.notify(("Sent to %s · %s (%s)"):format(item.agent, item.tab, item.t.address))
  end
  for _, key in ipairs(send_keys) do
    vim.keymap.set({ "n", "i" }, key, send, { buffer = buf })
  end
  vim.keymap.set("n", back_key, function()
    local edited = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_win_close(win, true)
    back(edited)
  end, { buffer = buf })
  vim.keymap.set({ "n", "i" }, close_key, function()
    vim.cmd.stopinsert()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end
