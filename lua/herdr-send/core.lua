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

function M.same_space(item, current)
  return item.machine == "local" and item.space == current
end

function M.ref_for(sel, same_space)
  if not sel then return nil end
  return M.ref(same_space and sel.rel or sel.abs, sel.a, sel.b)
end

function M.ref(path, a, b)
  if not a then return "@" .. path end
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

return M
