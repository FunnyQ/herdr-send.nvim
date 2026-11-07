package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
local M = require("herdr-send.core")
local render = require("herdr-send.ui.render")

local failures = 0
local function eq(name, got, want)
  if vim.deep_equal(got, want) then
    print("ok   " .. name)
  else
    failures = failures + 1
    print(("FAIL %s\n  got:  %s\n  want: %s"):format(name, vim.inspect(got), vim.inspect(want)))
  end
end

eq("parse local", M.parse({
  address = "t1gs", agent = "claude-code", status = "working", turn = 2,
  cwd = "/Users/q/p", where = "p / \u{f442}  discuss",
}), { agent = "claude-code", space = "p", tab = "discuss", machine = "local", id = "t1gs" })

eq("parse remote, plain tab name", M.parse({
  address = "omarchy/t1n", agent = "codex", status = "done",
  cwd = "/home/q/p", where = "p / 1",
}), { agent = "codex", space = "p", tab = "1", machine = "omarchy", id = "t1n" })

eq("parse keeps a CJK tab name", M.parse({ address = "t1", agent = "codex", status = "idle", where = "p / 討論" }).tab, "討論")
eq("parse strips a nerd font icon before a CJK tab name",
  M.parse({ address = "t1", agent = "codex", status = "idle", where = "p / \u{f442} 討論" }).tab, "討論")

eq("parse missing where", M.parse({ address = "t9", agent = "opencode", status = "idle", cwd = "/x" }),
  { agent = "opencode", space = "?", tab = "?", machine = "local", id = "t9" })

eq("is_agent keeps agents in a space", M.is_agent({ address = "omarchy/t1n", status = "done", where = "p / 1" }, "t1gs"), true)
eq("is_agent skips shells", M.is_agent({ address = "t2", where = "p / 1" }, "t1gs"), false)
eq("is_agent skips self", M.is_agent({ address = "t1gs", status = "idle", where = "p / 1" }, "t1gs"), false)
eq("is_agent skips hidden workers", M.is_agent({ address = "t4", status = "idle" }, "t1gs"), false)

local terms = {
  { address = "t1", where = "work / a" },
  { address = "t2", where = "p / main" },
  { address = "omarchy/t3", where = "p / 1" },
  { address = "t4", where = "work / b" },
}
local function shape(groups)
  return vim.tbl_map(function(g)
    return { g.name, vim.tbl_map(function(t) return t.address end, g.agents) }
  end, groups)
end
eq("group_spaces merges machines and puts current space first", shape(M.group_spaces(terms, "p")), {
  { "p", { "t2", "omarchy/t3" } },
  { "work", { "t1", "t4" } },
})
eq("group_spaces splits machines when asked", shape(M.group_spaces(terms, "p", true)), {
  { "p", { "t2" } },
  { "work", { "t1", "t4" } },
  { "p@omarchy", { "omarchy/t3" } },
})
eq("group_spaces keeps hc order without a current space", vim.tbl_map(function(g) return g.name end,
  M.group_spaces(terms, nil)), { "work", "p" })

eq("only_agent picks the sole agent of the current space", (M.only_agent(M.group_spaces(terms, "p", true), "p") or {}).address, "t2")
eq("only_agent skips a current space with several agents", M.only_agent(M.group_spaces(terms, "p"), "p"), nil)
eq("only_agent skips when the current space has no agent", M.only_agent(M.group_spaces(terms, "gone"), "gone"), nil)
eq("only_agent skips without a current space", M.only_agent(M.group_spaces({ terms[2] }, nil), nil), nil)

eq("retarget swaps an untouched reference", M.retarget({ "@a.lua#L1-2", "", "hi" }, "@a.lua#L1-2", "@/p/a.lua#L1-2"),
  { "@/p/a.lua#L1-2", "", "hi" })
eq("retarget keeps an edited reference", M.retarget({ "see a.lua", "hi" }, "@a.lua#L1-2", "@/p/a.lua#L1-2"),
  { "see a.lua", "hi" })
eq("retarget keeps lines without a reference", M.retarget({ "hi" }, nil, nil), { "hi" })

eq("keys wraps a single key", M.keys("<C-s>"), { "<C-s>" })
eq("keys keeps a list", M.keys({ "<C-s>", "<D-CR>" }), { "<C-s>", "<D-CR>" })

eq("same_space only for a local agent in the current space", {
  M.same_space({ machine = "local", space = "p" }, "p"),
  M.same_space({ machine = "omarchy", space = "p" }, "p"),
  M.same_space({ machine = "local", space = "work" }, "p"),
}, { true, false, false })

local sel = { rel = "src/a.lua", abs = "/Users/q/p/src/a.lua", a = 9, b = 3 }
eq("ref_for same space uses relative path", M.ref_for(sel, true), "@src/a.lua#L3-9")
eq("ref_for other space uses absolute path", M.ref_for(sel, false), "@/Users/q/p/src/a.lua#L3-9")
eq("ref single line is file only", M.ref("src/a.lua", 5, 5), "@src/a.lua")
eq("ref_for without selection", M.ref_for(nil, true), nil)

eq("ref file", M.ref("src/a.lua"), "@src/a.lua")
eq("ref range", M.ref("src/a.lua", 9, 3), "@src/a.lua#L3-9")

eq("initial_lines without ref", M.initial_lines(nil), { "" })
eq("initial_lines with ref", M.initial_lines("@a.lua#L1-2"), { "@a.lua#L1-2", "", "" })

local list = { { address = "t1" }, { address = "omarchy/t2" }, { address = "t3" } }
eq("last_first moves last used to top", vim.tbl_map(function(t) return t.address end, M.last_first(list, "t3")),
  { "t3", "t1", "omarchy/t2" })
eq("last_first keeps order without match", vim.tbl_map(function(t) return t.address end, M.last_first(list, "gone")),
  { "t1", "omarchy/t2", "t3" })
eq("last_first keeps order without last", vim.tbl_map(function(t) return t.address end, M.last_first(list, nil)),
  { "t1", "omarchy/t2", "t3" })

eq("chip wraps a label in slanted caps", render.chip("omarchy", "Remote", 9), {
  { "\u{e0ba}", "HerdrSendChipRemoteCap" },
  { " omarchy   ", "HerdrSendChipRemote" },
  { "\u{e0bc}", "HerdrSendChipRemoteCap" },
})
eq("tab_chunks draws rectangles and marks the active space", render.tab_chunks({ "p", "work" }, 2, 80), {
  { " p ", "HerdrSendChipTab" }, { " ", "FloatTitle" }, { " work ", "HerdrSendChipTabActive" },
})
eq("tab_chunks keeps the active tab visible when narrow", render.tab_chunks({ "aaaa", "bbbb", "cccc", "dddd" }, 1, 14), {
  { " aaaa ", "HerdrSendChipTabActive" }, { " ", "FloatTitle" }, { " bbbb ", "HerdrSendChipTab" },
  { " \u{2026}", "FloatTitle" },
})
eq("tab_chunks marks hidden tabs on both sides", render.tab_chunks({ "aaaa", "bbbb", "cccc", "dddd" }, 3, 14), {
  { "\u{2026} ", "FloatTitle" },
  { " bbbb ", "HerdrSendChipTab" }, { " ", "FloatTitle" }, { " cccc ", "HerdrSendChipTabActive" },
  { " \u{2026}", "FloatTitle" },
})

eq("model_label model and effort", M.model_label({ "env", "claude", "--model", "opus", "--effort", "low" }), "opus/low")
eq("model_label equals form", M.model_label({ "codex", "--model=gpt-5" }), "gpt-5")
eq("model_label ignores flags inside other tokens", M.model_label({ "env", "X=--model foo", "claude" }), "-")
eq("model_label none", M.model_label({ "claude" }), "-")

local new = { { name = "claude", cmd = { "claude" } } }
local other = { name = "other", agents = { { address = "t2" } } }
eq("with_new_agents adds an empty current space first", M.with_new_agents({ other }, "p", new),
  { { name = "p", agents = {}, new = new }, other })
eq("with_new_agents adds the current space when no agent exists anywhere", M.with_new_agents({}, "p", new),
  { { name = "p", agents = {}, new = new } })
eq("with_new_agents skips a current space that has agents",
  M.with_new_agents({ { name = "p", agents = { { address = "t1" } } } }, "p", new),
  { { name = "p", agents = { { address = "t1" } } } })
eq("with_new_agents skips outside herdr-app", M.with_new_agents({ other }, nil, new), { other })
eq("with_new_agents skips when no harness is installed", M.with_new_agents({ other }, "p", {}), { other })

eq("compose_size caps width on a large editor", M.compose_size(80, 198, 100), { width = 80, height = 30 })
eq("compose_size shrinks width to fit height", M.compose_size(80, 198, 20), { width = 53, height = 20 })
eq("compose_size shrinks to a narrow editor", M.compose_size(80, 50, 100), { width = 50, height = 19 })

eq("split_lines keeps a partial line for later", { M.split_lines("ab", "c\nde\nf") }, { { "abc", "de" }, "f" })
eq("split_lines without newline", { M.split_lines("", "abc") }, { {}, "abc" })

local raw = {
  address = "t1", state = "live",
  status = { app = "claude-code", state = "working", msg = "x" },
  labels = { where = "p / main" },
}
eq("ls_view flattens a raw terminal", M.ls_view(raw),
  { address = "t1", agent = "claude-code", status = "working", where = "p / main" })
eq("ls_view treats null status and labels as missing",
  M.ls_view({ address = "t2", status = vim.NIL, labels = { where = vim.NIL } }), { address = "t2" })

local function sorted_keys(t) local k = vim.tbl_keys(t) table.sort(k) return k end
local terms_by = M.apply_event({}, { seq = 1, terminals = { raw, { address = "t2", labels = {} } } })
eq("apply_event loads a snapshot", sorted_keys(terms_by), { "t1", "t2" })
M.apply_event(terms_by, { method = "event", params = {
  type = "status", terminal = "t1", data = { status = { app = "claude-code", state = "idle" } } } })
eq("apply_event merges a status change", M.ls_view(terms_by.t1).status, "idle")
M.apply_event(terms_by, { method = "event", params = {
  type = "status", terminal = "t1", data = { status = vim.NIL } } })
eq("apply_event clears status on null", M.ls_view(terms_by.t1).status, nil)
M.apply_event(terms_by, { method = "event", params = { type = "removed", terminal = "t2", data = {} } })
eq("apply_event drops a removed terminal", terms_by.t2, nil)
M.apply_event(terms_by, { method = "event", params = { type = "labels", terminal = "t9", data = { labels = { where = "q / 1" } } } })
eq("apply_event adds an unknown terminal", M.ls_view(terms_by.t9), { address = "t9", where = "q / 1" })
eq("apply_event replaces on a fresh snapshot", sorted_keys(M.apply_event(terms_by, { seq = 9, terminals = {} })), {})

local agents = {
  { address = "t1", status = "idle", where = "p / a" },
  { address = "t2", status = "working", where = "p / b" },
  { address = "t3", status = "done", where = "work / a" },
}
local function addr(t) return t and t.address end
eq("status_target picks last sent in the current space", addr(M.status_target(agents, "p", "t2")), "t2")
eq("status_target picks the sole agent of the current space", addr(M.status_target(agents, "work", "t1")), "t3")
eq("status_target skips a crowded current space without last sent", addr(M.status_target(agents, "p", "t3")), nil)
eq("status_target picks last sent outside herdr-app", addr(M.status_target(agents, nil, "t3")), "t3")
eq("status_target skips a gone last sent", addr(M.status_target(agents, nil, "t9")), nil)

eq("status_text shows the state", M.status_text({ status = "working" }), "● working")
eq("status_text is empty without agent", M.status_text(nil), "")

local function at(status) return { address = "t1", status = status } end
eq("finished on working to done", M.finished(at("working"), at("done")), true)
eq("finished skips blocked", { M.finished(at("working"), at("blocked")), M.finished(at("blocked"), at("done")) },
  { false, false })
eq("finished skips done to done", M.finished(at("done"), at("done")), false)
eq("finished skips a target change", M.finished(at("working"), { address = "t2", status = "done" }), false)
eq("finished skips without a previous target", M.finished(nil, at("done")), false)
eq("finished skips without a target", M.finished(at("working"), nil), false)

eq("project_slug replaces every non-alphanumeric", M.project_slug("/Users/q/.config/herdr-send.nvim"),
  "-Users-q--config-herdr-send-nvim")

local function line(t) return vim.json.encode(t) end
local function assistant(id, content) return line({ type = "assistant", message = { id = id, role = "assistant", content = content } }) end
eq("last_reply joins text blocks of the last assistant message", M.last_reply({
  '{"partial line from a tail read',
  assistant("m1", { { type = "text", text = "old" } }),
  line({ type = "user", message = { role = "user", content = "q" } }),
  assistant("m2", { { type = "thinking", thinking = "hmm" } }),
  assistant("m2", { { type = "text", text = "first" } }),
  assistant("m2", { { type = "tool_use", name = "Bash" } }),
  assistant("m2", { { type = "text", text = "second" } }),
  line({ type = "system", subtype = "turn_duration" }),
}), "first\n\nsecond")
eq("last_reply skips a final message without text", M.last_reply({
  assistant("m1", { { type = "text", text = "answer" } }),
  assistant("m2", { { type = "tool_use", name = "Bash" } }),
}), "answer")
eq("last_reply skips sidechain messages", M.last_reply({
  assistant("m1", { { type = "text", text = "main" } }),
  line({ type = "assistant", isSidechain = true, message = { id = "m2", content = { { type = "text", text = "sub" } } } }),
}), "main")
eq("last_reply is nil without assistant text", M.last_reply({ line({ type = "user" }) }), nil)

local turn_end = line({ type = "system", subtype = "turn_duration" })
local prompt = line({ type = "user", message = { role = "user", content = "q" } })
local reply = assistant("m1", { { type = "text", text = "a" } })
eq("turn_ended after turn_duration", M.turn_ended({ prompt, reply, turn_end, line({ type = "last-prompt" }) }), true)
eq("turn_ended waits for a reply written after the last turn_duration",
  M.turn_ended({ turn_end, prompt, reply, line({ type = "attachment" }) }), false)
eq("turn_ended waits without turn_duration", M.turn_ended({ prompt }), false)

eq("wrap_markdown breaks at the last space within width", M.wrap_markdown("aaa bbb ccc", 8), { "aaa bbb", "ccc" })
eq("wrap_markdown keeps short lines and turns blank lines into a space",
  M.wrap_markdown("a\n\nb", 8), { "a", " ", "b" })
eq("wrap_markdown keeps a code span whole", M.wrap_markdown("aa `b c` dd", 7), { "aa", "`b c`", "dd" })
eq("wrap_markdown keeps bold whole", M.wrap_markdown("aa **b c** dd", 8), { "aa", "**b c**", "dd" })
eq("wrap_markdown leaves fenced code alone", M.wrap_markdown("```\naaa bbb ccc\n\n```", 4),
  { "```", "aaa bbb ccc", " ", "```" })
eq("wrap_markdown breaks between CJK characters by byte width", M.wrap_markdown("一二三四", 9), { "一二三", "四" })
eq("wrap_markdown keeps CJK punctuation off the line start", M.wrap_markdown("一二三，四", 9), { "一二", "三，四" })
eq("wrap_markdown splits a word longer than width", M.wrap_markdown("abcdefghij", 4), { "abcd", "efgh", "ij" })
eq("wrap_markdown leaves tables alone", M.wrap_markdown("| aaa | bbb |", 4), { "| aaa | bbb |" })

eq("truncate keeps a short body", M.truncate("a\nb\n", 2), "a\nb")
eq("truncate cuts long bodies with an ellipsis", M.truncate("a\nb\nc", 2), "a\nb\n…")

os.exit(failures == 0 and 0 or 1)
