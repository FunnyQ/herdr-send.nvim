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

os.exit(failures == 0 and 0 or 1)
