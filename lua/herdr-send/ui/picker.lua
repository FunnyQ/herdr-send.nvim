local config = require("herdr-send.config")
local core = require("herdr-send.core")
local hc = require("herdr-send.hc")
local render = require("herdr-send.ui.render")
local compose = require("herdr-send.ui.compose")
local terminal = require("herdr-send.ui.terminal")

local function pick(sel, draft, action)
  local opts = config.options
  local self_where = vim.env.HC_TERMINAL_ID
    and (vim.json.decode(hc.run({ "get", vim.env.HC_TERMINAL_ID, "--json" })).labels or {}).where
  local current = self_where and core.split_where(self_where)
  local agents = vim.tbl_filter(function(t)
    return core.is_agent(t, vim.env.HC_TERMINAL_ID) and (not opts.filter or opts.filter(t))
  end, vim.json.decode(hc.run({ "ls", "--json" })).terminals)
  local last = hc.read_last()
  local installed = vim.tbl_filter(function(a) return vim.fn.executable(a.cmd[1]) == 1 end, opts.new_agents)
  local groups = core.with_new_agents(core.group_spaces(core.last_first(agents, last), current, opts.split_machines), current, installed)
  if #groups == 0 then
    vim.notify("No herdr agent found", vim.log.levels.WARN)
    return
  end
  local function spawn(new)
    -- hc run inherits the herdr-core server's env, not Neovim's; a login shell restores the user's PATH as herdr-app panes do
    local shell = vim.env.SHELL or "/bin/sh"
    local out = hc.run(vim.list_extend({ "run", "--bg", "--json", "--", shell, "-lic", '"$@"', shell }, vim.deepcopy(new.cmd)))
    if vim.v.shell_error ~= 0 then
      vim.notify("hc run failed: " .. out, vim.log.levels.ERROR)
      return
    end
    local address = vim.json.decode(out).address
    terminal(vim.tbl_extend("force", core.parse({ address = address, agent = new.name, where = self_where }), { t = { address = address } }))
  end
  local function open(item)
    if item.new then return spawn(item.new) end
    if action then return action(item) end
    local ref = core.ref_for(sel, core.same_space(item, current))
    local lines = draft and core.retarget(draft.lines, draft.ref, ref) or core.initial_lines(ref)
    compose(item, lines, function(edited) pick(sel, { lines = edited, ref = ref }) end)
  end
  local only = not draft and core.only_agent(groups, current)
  if only then
    open(vim.tbl_extend("force", core.parse(only), { t = only }))
    return
  end
  local names = vim.tbl_map(function(g) return g.name end, groups)
  local chip_width = 0
  local tab_width = 0
  for _, t in ipairs(agents) do
    local p = core.parse(t)
    chip_width = math.max(chip_width, #p.machine)
    tab_width = math.max(tab_width, vim.fn.strdisplaywidth(p.tab))
  end
  render.set_chip_hl()
  local idx = 1
  local function switch(picker, step)
    idx = (idx - 1 + step) % #groups + 1
    picker:refresh()
  end
  local models, screens = {}, {}
  local function model_of(t)
    models[t.address] = models[t.address]
      or core.model_label(vim.json.decode(hc.run({ "get", t.address, "--json" })).argv or {})
    return models[t.address]
  end
  local picker = Snacks.picker.pick({
    title = action and "Attach to agent" or "Send to agent",
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
      if groups[idx].new then
        return vim.tbl_map(function(new) return { new = new, text = new.name } end, groups[idx].new)
      end
      return vim.tbl_map(function(t)
        local p = core.parse(t)
        return vim.tbl_extend("force", p, {
          t = t,
          model = model_of(t),
          text = table.concat({ p.agent, p.tab, t.status, t.address }, " "),
        })
      end, groups[idx].agents)
    end,
    preview = function(ctx)
      if ctx.item.new then
        ctx.preview:reset()
        ctx.preview:set_lines({ "Start in a new terminal under Neovim:", "", table.concat(ctx.item.new.cmd, " ") })
        return
      end
      local addr = ctx.item.t.address
      screens[addr] = screens[addr] or vim.trim(hc.run({ "read", addr }))
      ctx.preview:reset()
      local lines = vim.split(screens[addr], "\n")
      ctx.preview:set_lines(lines)
      vim.wo[ctx.win].number = false
      vim.wo[ctx.win].relativenumber = false
      vim.wo[ctx.win].wrap = false
      vim.wo[ctx.win].signcolumn = "no"
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
      if item.new then return { { "＋ New " .. item.new.name, "Function" } } end
      local kind = item.machine == "local" and "Local" or "Remote"
      local ret = {
        { ("%-8s "):format(item.agent), "Function" },
        { ("%-12s "):format(item.model), "Special" },
        { item.tab .. (" "):rep(tab_width - vim.fn.strdisplaywidth(item.tab) + 1), "Title" },
        { ("%-8s "):format(item.t.status), render.status_hl[item.t.status] or "Comment" },
      }
      vim.list_extend(ret, render.chip(item.machine, kind, chip_width))
      table.insert(ret, { (" %-6s"):format(item.id), "Comment" })
      if item.t.address == last then
        table.insert(ret, { " ", "Normal" })
        vim.list_extend(ret, render.chip("last sent", "Last"))
      end
      return ret
    end,
    confirm = function(picker, item)
      picker:close()
      if item then vim.schedule(function() open(item) end) end
    end,
  })
  local update_titles = picker.update_titles
  picker.update_titles = function(self)
    update_titles(self)
    render.draw_tabs(self, names, idx)
  end
  picker:update_titles()
end

return pick
