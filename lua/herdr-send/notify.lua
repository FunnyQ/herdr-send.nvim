local core = require("herdr-send.core")

local uv = vim.uv
local claude_dir = vim.fn.expand("~/.claude")
local poll_ms, poll_tries = 250, 20
-- reads only the file tail, a final reply longer than this loses its start
local tail_bytes = 512 * 1024

local function await(fn, ...)
  local co = coroutine.running()
  local args = { ... }
  table.insert(args, function(...) coroutine.resume(co, ...) end)
  fn(unpack(args))
  return coroutine.yield()
end

local function read_file(path, size)
  local err, fd = await(uv.fs_open, path, "r", 438)
  if err then return nil end
  local _, stat = await(uv.fs_fstat, fd)
  local offset = size and math.max(0, stat.size - size) or 0
  local _, data = await(uv.fs_read, fd, stat.size - offset, offset)
  await(uv.fs_close, fd)
  return data
end

local function system(cmd)
  return await(vim.system, cmd, { text = true }).stdout or ""
end

local function session_for(pid)
  local data = read_file(("%s/sessions/%d.json"):format(claude_dir, pid))
  local ok, session = pcall(vim.json.decode, data or "")
  if ok and type(session) == "table" and session.sessionId then return session end
end

local function find_session(pids)
  local queue, depth = pids, 0
  while #queue > 0 and depth < 4 do
    local children = {}
    for _, pid in ipairs(queue) do
      local session = session_for(pid)
      if session then return session end
      for child in system({ "pgrep", "-P", tostring(pid) }):gmatch("%d+") do table.insert(children, tonumber(child)) end
    end
    queue, depth = children, depth + 1
  end
end

local function newest_jsonl(dir)
  local err, handle = await(uv.fs_scandir, dir)
  if err then return nil end
  local newest, newest_mtime
  while true do
    local name, kind = uv.fs_scandir_next(handle)
    if not name then break end
    if kind == "file" and name:match("%.jsonl$") then
      local _, stat = await(uv.fs_stat, dir .. "/" .. name)
      if stat and (not newest_mtime or stat.mtime.sec > newest_mtime) then
        newest, newest_mtime = dir .. "/" .. name, stat.mtime.sec
      end
    end
  end
  return newest
end

local function transcript_for(address)
  local ok, term = pcall(vim.json.decode, system({ "hc", "get", address, "--json" }))
  if not ok or type(term) ~= "table" then return nil end
  local fg = type(term.foreground) == "table" and term.foreground or {}
  local pids = vim.tbl_filter(function(p) return type(p) == "number" end, { fg.pid, term.pid })
  local session = find_session(pids)
  local cwd = session and session.cwd or term.cwd
  if type(cwd) ~= "string" then return nil end
  local dir = ("%s/projects/%s"):format(claude_dir, core.project_slug(cwd))
  if session then return ("%s/%s.jsonl"):format(dir, session.sessionId) end
  return newest_jsonl(dir)
end

local function body_for(view)
  if view.agent ~= "claude-code" or view.address:find("/") then return nil end
  local path = transcript_for(view.address)
  if not path then return nil end
  local lines = {}
  -- hc reports done before Claude Code flushes the final reply; wait for its turn_duration line
  for _ = 1, poll_tries do
    lines = vim.split(read_file(path, tail_bytes) or "", "\n", { plain = true })
    if core.turn_ended(lines) then break end
    local co = coroutine.running()
    vim.defer_fn(function() coroutine.resume(co) end, poll_ms)
    coroutine.yield()
  end
  return core.last_reply(lines)
end

local function notify_config()
  local ok, cfg = pcall(function() return require("notify")._config() end)
  return ok and cfg or nil
end

-- mirrors nvim-notify's wrapped-default width, which splits lines by byte count
local function notify_width()
  local cfg = notify_config()
  local columns = vim.o.columns
  return math.max(10, math.min(cfg and cfg.max_width() or math.floor(columns * 0.3), columns - 1))
end

local function busy()
  return vim.iter(vim.api.nvim_list_wins()):any(function(w) return vim.w[w].herdr_send_busy end)
end

local function as_markdown(win)
  vim.bo[vim.api.nvim_win_get_buf(win)].filetype = "markdown"
  -- a nowrap window scrolls sideways into blank columns even when every line fits
  vim.wo[win].wrap = true
end

-- nvim-notify asks keep() each time timeout fires, so a short timeout polls it
local function linger(base, markdown)
  local win, deadline
  base.timeout = 100
  base.keep = function()
    if busy() then deadline = nil end
    return not deadline or vim.uv.now() < deadline or vim.api.nvim_get_current_win() == win
  end
  base.on_open = function(w)
    win = w
    if markdown then as_markdown(w) end
    local ns = vim.on_key(function(key)
      local name = vim.fn.keytrans(key)
      if name:find("MouseMove") then return end
      vim.schedule(function()
        if not vim.api.nvim_win_is_valid(win) then return end
        if name:find("Mouse") or name:find("ScrollWheel") or name:find("Drag") or name:find("Release") then
          local pos = vim.fn.getmousepos()
          if pos.winid == win then
            if name == "<LeftMouse>" and core.on_close_button(pos, vim.api.nvim_win_get_width(win)) then
              vim.api.nvim_win_close(win, true)
            end
            return
          end
        end
        if deadline or busy() or vim.api.nvim_get_current_win() == win then return end
        deadline = vim.uv.now() + require("herdr-send.config").options.notify_linger_ms
      end)
    end)
    vim.api.nvim_create_autocmd("WinClosed", {
      pattern = tostring(w), once = true,
      callback = function() vim.on_key(nil, ns) end,
    })
  end
end

return function(view)
  coroutine.wrap(function()
    local reply = body_for(view)
    vim.schedule(function()
      local base = { title = view.agent .. " done" }
      local cfg = notify_config()
      if cfg then base.title = { base.title, vim.fn.strftime(cfg.time_formats().notification) .. " [X]" } end
      local body = "done"
      if reply then
        body = vim.trim(table.concat(core.wrap_markdown(reply, notify_width()), "\n"))
      end
      linger(base, reply ~= nil)
      local opts = core.reply_opts(base, require("herdr-send.config").options.notify)
      -- nvim-notify's compact render prefixes the first line with "icon | title:", pushing it past max_width
      if reply and opts.render == "compact" then body = "\n" .. body end
      vim.notify(body, vim.log.levels.INFO, opts)
    end)
  end)()
end
