local M = {}

function M.run(args)
  return vim.fn.system(vim.list_extend({ "hc" }, args))
end

-- one global "last used" address, per-project history if switching projects often
local last_file = vim.fn.stdpath("state") .. "/herdr-send-last"

function M.read_last()
  local ok, lines = pcall(vim.fn.readfile, last_file)
  return ok and lines[1] or nil
end

function M.write_last(address)
  vim.fn.writefile({ address }, last_file)
end

return M
