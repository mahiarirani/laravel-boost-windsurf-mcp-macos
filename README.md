# Laravel Boost MCP for macOS

A shell script that lets [Windsurf](https://windsurf.com) connect to [Laravel Boost](https://laravel.com/docs/12.x/boost) MCP when your app runs inside [Laravel Sail](https://laravel.com/docs/sail) or Docker Compose.

## Why?

Windsurf launches MCP servers from your home directory — not your project folder. So `php artisan boost:mcp` can't find `artisan`, and even if it could, it needs to run **inside the container** where your app lives.

This script automatically finds your active Laravel project and runs `boost:mcp` through Sail or Docker Compose.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mahiarirani/laravel-boost-windsurf-mcp-macos/main/init.sh \
  -o ~/.codeium/laravel-boost-mcp.sh && chmod +x ~/.codeium/laravel-boost-mcp.sh
```

## Configure Windsurf

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "/Users/YOUR_USERNAME/.codeium/laravel-boost-mcp.sh"
    }
  }
}
```

> Replace `YOUR_USERNAME` with your macOS username. Windsurf doesn't expand `~`.

Then refresh MCP servers: **Windsurf Settings → Cascade → MCP Servers → Refresh**.

One config works for all your Laravel projects.

## Prerequisites

- **macOS**
- **Docker** running with your containers up (`sail up -d`)
- **Laravel Boost** installed in your project (`composer require laravel/boost --dev`)

## How It Works

1. **Finds your project** — checks Windsurf process working directories via `lsof`, then falls back to Windsurf's `code_tracker` files, then scans common directories (`~/Projects`, `~/Code`, `~/Sites`, `~/Desktop`) for recently modified Laravel apps
2. **Picks the right runner** — Sail → Docker Compose → local PHP
3. **Launches** `artisan boost:mcp` inside the container

You can also force a specific project with the `BOOST_WORKSPACE` env var:

```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "/Users/YOUR_USERNAME/.codeium/laravel-boost-mcp.sh",
      "env": {
        "BOOST_WORKSPACE": "/Users/YOUR_USERNAME/Projects/my-app"
      }
    }
  }
}
```

## Debug

Logs are written to `~/.codeium/laravel-boost-mcp.log`.

```bash
cat ~/.codeium/laravel-boost-mcp.log
```

## License

MIT
