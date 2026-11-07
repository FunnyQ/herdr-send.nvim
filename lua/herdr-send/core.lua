local M = {}

function M.split_where(where)
  local space, tab = (where or ""):match("^(.-) / (.*)$")
  return space or "?", tab
end

local function strip_icons(s)
  local cp = vim.fn.char2nr(s)
  while (cp >= 0xE000 and cp <= 0xF8FF) or cp >= 0xF0000 do
    s = vim.fn.strcharpart(s, 1)
    cp = vim.fn.char2nr(s)
  end
  return vim.trim(s)
end

function M.parse(t)
  local space, tab = M.split_where(t.where)
  local machine, id = t.address:match("^(.-)/(.*)$")
  return {
    agent = t.agent,
    space = space,
    tab = strip_icons(tab or "?"),
    machine = machine or "local",
    id = id or t.address,
  }
end

function M.is_agent(t, self_id)
  return t.status ~= nil and t.where ~= nil and t.address ~= self_id
end

function M.group_spaces(terminals, current, split_machines)
  local groups, by_name = {}, {}
  for _, t in ipairs(terminals) do
    local space = M.split_where(t.where)
    local machine = t.address:match("^(.-)/")
    local name = (split_machines and machine) and (space .. "@" .. machine) or space
    if not by_name[name] then
      by_name[name] = { name = name, agents = {} }
      table.insert(groups, by_name[name])
    end
    table.insert(by_name[name].agents, t)
  end
  for i, g in ipairs(groups) do
    if g.name == current then table.insert(groups, 1, table.remove(groups, i)) break end
  end
  return groups
end

function M.only_agent(groups, current)
  local g = groups[1]
  if g and current and g.name == current and #g.agents == 1 then return g.agents[1] end
end

function M.with_new_agents(groups, current, new_agents)
  if not current or #new_agents == 0 then return groups end
  for _, g in ipairs(groups) do
    if g.name == current then return groups end
  end
  return { { name = current, agents = {}, new = new_agents }, unpack(groups) }
end

function M.keys(key)
  return type(key) == "table" and key or { key }
end

function M.same_space(item, current)
  return item.machine == "local" and item.space == current
end

function M.ref_for(sel, same_space)
  if not sel then return nil end
  return M.ref(same_space and sel.rel or sel.abs, sel.a, sel.b)
end

function M.ref(path, a, b)
  if not a or a == b then return "@" .. path end
  if a > b then a, b = b, a end
  return ("@%s#L%d-%d"):format(path, a, b)
end

function M.last_first(terminals, last)
  local out = {}
  for _, t in ipairs(terminals) do
    if t.address == last then table.insert(out, 1, t) else table.insert(out, t) end
  end
  return out
end

function M.initial_lines(ref)
  if not ref then return { "" } end
  return { ref, "", "" }
end

function M.retarget(lines, old_ref, new_ref)
  if not old_ref or lines[1] ~= old_ref then return lines end
  local out = vim.list_slice(lines)
  out[1] = new_ref
  return out
end

-- a terminal cell is about twice as tall as it is wide, so 4:3 landscape is rows = cols * 3 / 4 / 2
local rows_per_col = 3 / 4 / 2

function M.compose_size(max_width, avail_width, avail_height)
  local width = math.min(max_width, avail_width, math.floor(avail_height / rows_per_col))
  return { width = width, height = math.min(avail_height, math.floor(width * rows_per_col + 0.5)) }
end

function M.model_label(argv)
  local function flag(name)
    for i, arg in ipairs(argv) do
      if arg == name then return argv[i + 1] end
      local v = arg:match("^" .. vim.pesc(name) .. "=(.+)$")
      if v then return v end
    end
  end
  local model, effort = flag("--model"), flag("--effort")
  if not model then return "-" end
  return effort and (model .. "/" .. effort) or model
end

function M.split_lines(pending, chunk)
  local lines = vim.split(pending .. chunk, "\n", { plain = true })
  local rest = table.remove(lines)
  return lines, rest
end

local function present(v)
  if v ~= vim.NIL then return v end
end

function M.ls_view(t)
  local status = present(t.status)
  return {
    address = t.address,
    agent = status and status.app,
    status = status and status.state,
    where = present((present(t.labels) or {}).where),
  }
end

function M.apply_event(terms, msg)
  if msg.terminals then
    for k in pairs(terms) do terms[k] = nil end
    for _, t in ipairs(msg.terminals) do terms[t.address] = t end
    return terms
  end
  local ev = msg.params
  if not ev or not ev.terminal then return terms end
  if ev.type == "finished" or ev.type == "removed" then
    terms[ev.terminal] = nil
  else
    terms[ev.terminal] = vim.tbl_extend("force", terms[ev.terminal] or { address = ev.terminal }, ev.data or {})
  end
  return terms
end

function M.status_target(agents, current, last)
  local in_space = {}
  for _, t in ipairs(agents) do
    local here = not current or M.split_where(t.where) == current
    if here and t.address == last then return t end
    if current and here then table.insert(in_space, t) end
  end
  if #in_space == 1 then return in_space[1] end
end

function M.status_text(agent)
  return agent and ("● " .. agent.status) or ""
end

return M
