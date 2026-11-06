local M = {}

M.config = {
  send_key = "<C-s>",
  chip = {
    local_hl = "DiffAdd",
    remote_hl = "DiffChange",
    last_hl = "Search",
    tab_hl = "TabLine",
    tab_active_hl = "TabLineSel",
  },
  split_machines = false,
  filter = nil,
}

local status_hl = {
  working = "DiagnosticWarn",
  idle = "DiagnosticOk",
  done = "DiagnosticInfo",
  blocked = "DiagnosticError",
  error = "DiagnosticError",
}

local function split_where(where)
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
  local space, tab = split_where(t.where)
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
    local space = split_where(t.where)
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

-- one global "last used" address, per-project history if switching projects often
local last_file = vim.fn.stdpath("state") .. "/herdr-send-last"

local function read_last()
  local ok, lines = pcall(vim.fn.readfile, last_file)
  return ok and lines[1] or nil
end

function M.initial_lines(ref)
  if not ref then return { "" } end
  return { ref, "", "" }
end

local function hc(args)
  return vim.fn.system(vim.list_extend({ "hc" }, args))
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

local function set_chip_hl()
  local c = M.config.chip
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

local function draw_tabs(picker, names, idx)
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

local function compose(item, ref)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  local lines = M.initial_lines(ref)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local width, height = math.floor(vim.o.columns * 0.6), 12
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    width = width, height = height,
    row = math.floor((vim.o.lines - height) / 2), col = math.floor((vim.o.columns - width) / 2),
    title = (" → %s · %s "):format(item.agent, item.tab), title_pos = "center",
    footer = (" %s send · q cancel "):format(M.config.send_key), footer_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  vim.cmd.startinsert()
  vim.keymap.set({ "n", "i" }, M.config.send_key, function()
    local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    vim.cmd.stopinsert()
    vim.api.nvim_win_close(win, true)
    if text == "" then
      vim.notify("Empty message, nothing sent", vim.log.levels.WARN)
      return
    end
    local out = hc({ "send", item.t.address, "--", text })
    if vim.v.shell_error ~= 0 then
      vim.notify("hc send failed: " .. out, vim.log.levels.ERROR)
      return
    end
    vim.fn.writefile({ item.t.address }, last_file)
    vim.notify(("Sent to %s · %s (%s)"):format(item.agent, item.tab, item.t.address))
  end, { buffer = buf })
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
end

function M.pick(sel)
  local self_where = vim.env.HC_TERMINAL_ID
    and (vim.json.decode(hc({ "get", vim.env.HC_TERMINAL_ID, "--json" })).labels or {}).where
  local current = self_where and split_where(self_where)
  local agents = vim.tbl_filter(function(t)
    return M.is_agent(t, vim.env.HC_TERMINAL_ID) and (not M.config.filter or M.config.filter(t))
  end, vim.json.decode(hc({ "ls", "--json" })).terminals)
  local last = read_last()
  local groups = M.group_spaces(M.last_first(agents, last), current, M.config.split_machines)
  if #groups == 0 then
    vim.notify("No herdr agent found", vim.log.levels.WARN)
    return
  end
  local names = vim.tbl_map(function(g) return g.name end, groups)
  local chip_width = 0
  local tab_width = 0
  for _, t in ipairs(agents) do
    local p = M.parse(t)
    chip_width = math.max(chip_width, #p.machine)
    tab_width = math.max(tab_width, vim.fn.strdisplaywidth(p.tab))
  end
  set_chip_hl()
  local idx = 1
  local function switch(picker, step)
    idx = (idx - 1 + step) % #groups + 1
    picker:refresh()
  end
  local models, screens = {}, {}
  local function model_of(t)
    models[t.address] = models[t.address]
      or M.model_label(vim.json.decode(hc({ "get", t.address, "--json" })).argv or {})
    return models[t.address]
  end
  local picker = Snacks.picker.pick({
    title = "Send to agent",
    focus = "list",
    layout = {
      layout = {
        backdrop = false,
        width = 0.5,
        min_width = 80,
        height = 0.8,
        min_height = 30,
        box = "vertical",
        border = true,
        title = "{title}",
        title_pos = "center",
        { win = "input", height = 1, border = "bottom" },
        { win = "list", height = 6, border = "none" },
        { win = "preview", border = "top" },
      },
    },
    finder = function()
      return vim.tbl_map(function(t)
        local p = M.parse(t)
        return vim.tbl_extend("force", p, {
          t = t,
          model = model_of(t),
          text = table.concat({ p.agent, p.tab, t.status, t.address }, " "),
        })
      end, groups[idx].agents)
    end,
    preview = function(ctx)
      local addr = ctx.item.t.address
      screens[addr] = screens[addr] or vim.trim(hc({ "read", addr }))
      ctx.preview:reset()
      local lines = vim.split(screens[addr], "\n")
      ctx.preview:set_lines(lines)
      vim.wo[ctx.win].number = false
      vim.wo[ctx.win].relativenumber = false
      vim.api.nvim_win_call(ctx.win, function()
        vim.api.nvim_win_set_cursor(0, { #lines, 0 })
        vim.cmd("normal! zb")
      end)
    end,
    sort = { fields = { "score:desc", "idx" } },
    actions = {
      space_prev = function(picker) switch(picker, -1) end,
      space_next = function(picker) switch(picker, 1) end,
    },
    win = {
      list = { keys = { h = "space_prev", l = "space_next", ["<Left>"] = "space_prev", ["<Right>"] = "space_next" } },
    },
    format = function(item)
      local kind = item.machine == "local" and "Local" or "Remote"
      local ret = {
        { ("%-8s "):format(item.agent), "Function" },
        { ("%-12s "):format(item.model), "Special" },
        { item.tab .. (" "):rep(tab_width - vim.fn.strdisplaywidth(item.tab) + 1), "Title" },
        { ("%-8s "):format(item.t.status), status_hl[item.t.status] or "Comment" },
      }
      vim.list_extend(ret, M.chip(item.machine, kind, chip_width))
      table.insert(ret, { (" %-6s"):format(item.id), "Comment" })
      if item.t.address == last then
        table.insert(ret, { " ", "Normal" })
        vim.list_extend(ret, M.chip("last sent", "Last"))
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if item then compose(item, M.ref_for(sel, M.same_space(item, current))) end
    end,
  })
  local update_titles = picker.update_titles
  picker.update_titles = function(self)
    update_titles(self)
    draw_tabs(self, names, idx)
  end
  picker:update_titles()
end

function M.send()
  M.pick(nil)
end

function M.send_selection()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  M.pick({ rel = vim.fn.expand("%:."), abs = vim.fn.expand("%:p"), a = a, b = b })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
