local M = {}

local server = require("preview-md.server")
local browser = require("preview-md.browser")

function M.preview(filepath)
  filepath = filepath and vim.fn.expand(filepath) or vim.api.nvim_buf_get_name(0)

  if filepath == "" then
    vim.notify("[preview-md] No file — save the buffer first.", vim.log.levels.ERROR)
    return
  end

  filepath = vim.fn.fnamemodify(filepath, ":p")
  local ext = vim.fn.fnamemodify(filepath, ":e"):lower()
  local supported = { md = true, markdown = true, mdx = true, html = true, htm = true }

  if not supported[ext] then
    vim.notify("[preview-md] Unsupported file type: " .. ext, vim.log.levels.WARN)
    return
  end

  server.watch(filepath, function(port)
    browser.open("http://127.0.0.1:" .. port)
  end)
end

function M.stop()
  server.stop()
end

function M.setup(opts)
  opts = opts or {}

  vim.api.nvim_create_user_command("Preview", function(args)
    M.preview(args.args ~= "" and args.args or nil)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Open a browser preview of the current markdown/HTML file",
  })

  vim.api.nvim_create_user_command("PreviewStop", function()
    M.stop()
  end, { desc = "Stop the preview server" })
end

return M
