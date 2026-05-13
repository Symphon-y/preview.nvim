local M = {}

local uv = vim.uv or vim.loop

local state = {
  job = nil,
  port = nil,
  file = nil,
  python = nil,
}

local function plugin_root()
  -- This file lives at lua/preview-md/server.lua; go up three levels.
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":h:h:h")
end

local function find_python()
  for _, cmd in ipairs({ "python3", "python", "py" }) do
    if vim.fn.executable(cmd) == 1 or vim.fn.exepath(cmd) ~= "" then
      return cmd
    end
  end
end

-- URL-encode a string for use in a query parameter.
local function urlencode(s)
  return (s:gsub("([^%w%-%.%_%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- Send GET /switch?file=<path> to the running server via a raw TCP connection.
local function switch_file(filepath)
  local client = uv.new_tcp()
  client:connect("127.0.0.1", state.port, function(err)
    if err then
      if not client:is_closing() then client:close() end
      return
    end
    local req = table.concat({
      "GET /switch?file=" .. urlencode(filepath) .. " HTTP/1.0",
      "Host: 127.0.0.1",
      "Connection: close",
      "",
      "",
    }, "\r\n")
    client:write(req)
    client:read_start(function(_, chunk)
      if not chunk and not client:is_closing() then
        client:close()
      end
    end)
  end)
end

-- Start the server for `filepath` and call `on_ready(port)` once it is up.
function M.watch(filepath, on_ready)
  if state.job and state.port then
    if state.file ~= filepath then
      switch_file(filepath)
      state.file = filepath
    end
    on_ready(state.port)
    return
  end

  local python = find_python()
  if not python then
    vim.notify("[preview-md] Python 3 not found — install it to use this plugin.", vim.log.levels.ERROR)
    return
  end
  state.python = python

  local script = plugin_root() .. "/server/server.py"
  local port_received = false

  -- "py" is the Windows Python Launcher; pass -3 to force Python 3.
  local argv = python == "py"
    and { python, "-3", script, "--file", filepath, "--port", "0" }
    or { python, script, "--file", filepath, "--port", "0" }

  state.job = vim.fn.jobstart(
    argv,
    {
      on_stdout = function(_, data)
        if port_received then return end
        for _, line in ipairs(data) do
          local port = tonumber(vim.trim(line))
          if port and port > 0 then
            port_received = true
            state.port = port
            state.file = filepath
            vim.schedule(function() on_ready(port) end)
            break
          end
        end
      end,
      on_stderr = function(_, data)
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              vim.notify("[preview-md] " .. line, vim.log.levels.WARN)
            end)
          end
        end
      end,
      on_exit = function()
        state.job = nil
        state.port = nil
        state.file = nil
      end,
      stdout_buffered = false,
    }
  )
end

function M.stop()
  if state.job then
    vim.fn.jobstop(state.job)
    state.job = nil
    state.port = nil
    state.file = nil
    vim.notify("[preview-md] Preview server stopped.", vim.log.levels.INFO)
  else
    vim.notify("[preview-md] No preview server running.", vim.log.levels.INFO)
  end
end

return M
