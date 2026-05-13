if vim.g.loaded_preview_md then return end
vim.g.loaded_preview_md = true

if vim.fn.has("nvim-0.7") == 0 then
  vim.notify("[preview-md] Requires Neovim 0.7+", vim.log.levels.ERROR)
  return
end

require("preview-md").setup()
