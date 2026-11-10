local config = require("herdr-send.config")
local core = require("herdr-send.core")
local hc = require("herdr-send.hc")
local notify = require("herdr-send.notify")
local render = require("herdr-send.ui.render")

local M = {}

local reconnect_ms = 5000
local terms, pending, started = {}, "", false
local text, hl, prev = "", nil, nil

local function refresh()
  local self_id = vim.env.HC_TERMINAL_ID
  local self_where = terms[self_id or ""] and core.ls_view(terms[self_id]).where
  local current = self_where and core.split_where(self_where)
  local filter = config.options.filter
  local agents = {}
  for _, t in pairs(terms) do
    local view = core.ls_view(t)
    if core.is_agent(view, self_id) and (not filter or filter(view)) then table.insert(agents, view) end
  end
  local target = core.status_target(agents, current, hc.read_last())
  if config.options.notify_on_done and core.finished(prev, target) then notify.done(target) end
  prev = target
  local new_text = core.status_text(target)
  hl = target and render.status_hl[target.status]
  if new_text ~= text then
    text = new_text
    -- lualine caches its statusline string between its own 1000 ms refreshes, so redrawstatus repaints stale text
    if package.loaded.lualine then
      package.loaded.lualine.refresh({ place = { "statusline" } })
    else
      vim.cmd.redrawstatus()
    end
  end
end

local function on_chunk(chunk)
  local lines
  lines, pending = core.split_lines(pending, chunk)
  for _, line in ipairs(lines) do
    core.apply_event(terms, vim.json.decode(line))
  end
  if #lines > 0 then refresh() end
end

local function start()
  pending = ""
  hc.stream({ "events", "--json" }, function(_, chunk)
    if chunk then vim.schedule(function() on_chunk(chunk) end) end
  end, function()
    vim.schedule(function()
      terms = {}
      refresh()
      vim.defer_fn(start, reconnect_ms)
    end)
  end)
end

function M.start()
  if not started then
    started = true
    if vim.fn.executable("hc") == 1 then start() end
  end
end

function M.text()
  M.start()
  return text
end

function M.hl()
  return hl
end

return M
