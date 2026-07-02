local M = {}

-- Detect WSL: Neovim runs as a Linux binary here, so has("win32") is false,
-- but there's no native xdg-open. We have to reach out to the Windows host.
local function is_wsl()
  if vim.fn.has("wsl") == 1 then
    return true
  end
  if vim.env.WSL_DISTRO_NAME or vim.env.WSL_INTEROP then
    return true
  end
  local ok, version = pcall(vim.fn.readfile, "/proc/version")
  if ok and version[1] and version[1]:lower():find("microsoft") then
    return true
  end
  return false
end

function M.open(url)
  local cmd
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    -- The empty string is the window title; required when the URL contains & or ?
    cmd = { "cmd", "/c", "start", "", url }
  elseif vim.fn.has("mac") == 1 then
    cmd = { "open", url }
  elseif is_wsl() then
    -- Prefer wslview (from wslu) if present; otherwise reach the Windows host.
    if vim.fn.executable("wslview") == 1 then
      cmd = { "wslview", url }
    elseif vim.fn.executable("explorer.exe") == 1 then
      -- explorer.exe opens URLs in the default Windows browser. It exits
      -- non-zero even on success, which is harmless with a detached job.
      cmd = { "explorer.exe", url }
    else
      cmd = { "powershell.exe", "-NoProfile", "-Command", "Start-Process", url }
    end
  elseif vim.fn.executable("xdg-open") == 1 then
    cmd = { "xdg-open", url }
  else
    vim.notify("preview-md: no browser opener found (install xdg-open)", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart(cmd, { detach = true })
end

return M
