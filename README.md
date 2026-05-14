# preview.nvim

A Neovim plugin that opens a live browser preview of markdown and HTML files. Edits on disk are reflected instantly via Server-Sent Events
<img src="assets/demo/demo.gif" />

## Features

- `:PreviewStart` — open the current buffer in your default browser
- Live reload on every file save (SSE, ~250 ms latency)
- GitHub Dark–styled markdown rendering (via [marked.js](https://marked.js.org) + [github-markdown-css](https://github.com/sindresorhus/github-markdown-css))
- HTML file preview with the same live-reload behaviour
- Switch files without restarting the server — `:PreviewStart other.md` hot-swaps the watched file
- Zero Python dependencies — server uses stdlib only
- Cross-platform: Windows, macOS, Linux

## Requirements

- Neovim 0.7+
- Python 3.6+ (`python3` or `python` on `$PATH`)

## Installation

**lazy.nvim**

```lua
{ "Symphon-y/preview.nvim" }
```

**packer.nvim**

```lua
use "Symphon-y/preview.nvim"
```

**vim-plug**

```vim
Plug 'Symphon-y/preview.nvim'
```

The plugin registers itself automatically via `plugin/preview-md.lua`. No explicit `setup()` call is required unless you want to customise options (none yet).

## Usage

| Command | Description |
|---|---|
| `:PreviewStart` | Preview the current buffer |
| `:PreviewStart path/to/file.md` | Preview a specific file |
| `:PreviewStop` | Stop the preview server |

Open a markdown file and run `:PreviewStart`. A browser tab opens at `http://127.0.0.1:<port>`. The page updates automatically whenever you save the file.

## How it works

```
Neovim                           Python (stdlib HTTP server)
──────                           ──────────────────────────
:PreviewStart  ──spawn──────────────► server.py --file <path> --port 0
          ◄── prints port ──────
          ── open browser ─────► http://127.0.0.1:<port>

                                   GET /        HTML shell + marked.js
                                   GET /content raw file bytes
                                   GET /events  SSE stream (live reload)
                                   GET /switch  hot-swap watched file

file saved on disk
  └─ watcher detects mtime change
       └─ SSE pushes "reload"
            └─ browser re-fetches /content and re-renders
```

The server is started once per Neovim session and stays alive until `:PreviewStop` or Neovim exits. Switching to a different file sends a single HTTP request to the running server rather than restarting it.

## Supported file types

| Extension | Rendering |
|---|---|
| `.md`, `.markdown`, `.mdx` | Client-side via marked.js (GFM) |
| `.html`, `.htm` | Raw HTML injected into the preview frame |

## License

MIT
