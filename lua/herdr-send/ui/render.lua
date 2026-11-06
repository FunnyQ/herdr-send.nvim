local config = require("herdr-send.config")

local M = {}

M.status_hl = {
  working = "DiagnosticWarn",
  idle = "DiagnosticOk",
  done = "DiagnosticInfo",
  blocked = "DiagnosticError",
  error = "DiagnosticError",
}

function M.chip(label, kind, width)
  local hl = "HerdrSendChip" .. kind
  return {
    { "\u{e0ba}", hl .. "Cap" },
    { (" %-" .. (width or #label) .. "s "):format(label), hl },
    { "\u{e0bc}", hl .. "Cap" },
  }
end

function M.tab_chunks(names, idx, width)
  local function w(i) return vim.fn.strdisplaywidth(names[i]) + 2 end
  local lo, hi, used = idx, idx, w(idx)
  local grew = true
  while grew do
    grew = false
    if lo > 1 and used + 1 + w(lo - 1) <= width then
      lo, used, grew = lo - 1, used + 1 + w(lo - 1), true
    end
    if hi < #names and used + 1 + w(hi + 1) <= width then
      hi, used, grew = hi + 1, used + 1 + w(hi + 1), true
    end
  end
  local out = {}
  if lo > 1 then table.insert(out, { "\u{2026} ", "FloatTitle" }) end
  for i = lo, hi do
    if i > lo then table.insert(out, { " ", "FloatTitle" }) end
    table.insert(out, { " " .. names[i] .. " ", i == idx and "HerdrSendChipTabActive" or "HerdrSendChipTab" })
  end
  if hi < #names then table.insert(out, { " \u{2026}", "FloatTitle" }) end
  return out
end

local function blend(a, b, t)
  local function ch(c, shift) return math.floor(c / 2 ^ shift) % 256 end
  local out = 0
  for _, shift in ipairs({ 16, 8, 0 }) do
    out = out + math.floor(ch(a, shift) * (1 - t) + ch(b, shift) * t + 0.5) * 2 ^ shift
  end
  return out
end

function M.set_chip_hl()
  local c = config.options.chip
  local sources = { Local = c.local_hl, Remote = c.remote_hl, Last = c.last_hl, Tab = c.tab_hl, TabActive = c.tab_active_hl }
  local normal_fg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg
  for kind, src in pairs(sources) do
    local hl = vim.api.nvim_get_hl(0, { name = src, link = false })
    local fg = hl.fg or normal_fg
    if kind == "TabActive" and hl.bg then
      hl.bg = blend(hl.bg, normal_fg, 0.25)
    end
    vim.api.nvim_set_hl(0, "HerdrSendChip" .. kind, { bg = hl.bg, fg = fg, bold = kind ~= "Tab" })
    vim.api.nvim_set_hl(0, "HerdrSendChip" .. kind .. "Cap", { fg = hl.bg })
  end
end

function M.draw_tabs(picker, names, idx)
  local wins = { picker.layout.root }
  vim.list_extend(wins, vim.tbl_values(picker.layout.wins))
  vim.list_extend(wins, vim.tbl_values(picker.layout.box_wins))
  for _, win in ipairs(wins) do
    if win.opts.title and win:valid() and win ~= picker.layout.wins.preview then
      local chunks = M.tab_chunks(names, idx, vim.api.nvim_win_get_width(win.win) - 4)
      vim.api.nvim_win_set_config(win.win, { title = chunks, title_pos = "center" })
    end
  end
end

return M
