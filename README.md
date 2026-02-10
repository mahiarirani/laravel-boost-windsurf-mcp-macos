# Laravel Boost MCP — Sail / Docker Bridge

A wrapper script that connects MCP clients (Windsurf, Claude Code, Cursor, etc.) to [Laravel Boost](https://laravel.com/docs/12.x/boost) running inside [Laravel Sail](https://laravel.com/docs/sail) or Docker Compose containers.

**One config, all projects** — no per-project paths needed.

## The Problem

Laravel Boost's MCP server runs with `php artisan boost:mcp`, but when your app runs inside Sail/Docker the host can't reach the containerized PHP/database. MCP clients also don't always `cd` into your project, so `artisan` is never found.

This script:

1. Walks up from `$PWD` to find the Laravel project root (`artisan`)
2. Picks the best runner: **Sail** → **Docker Compose** → **local PHP**
3. Launches `artisan boost:mcp` inside the container

## Prerequisites

- **Docker** running
- **Laravel Sail** or a `docker-compose.yml` in your project
- **Laravel Boost** installed (`composer require laravel/boost --dev`)
- Containers running (`sail up -d`) before the MCP server starts

## Setup

### 1. Install the script

```bash
cp init.sh ~/.codeium/laravel-boost-mcp.sh
chmod +x ~/.codeium/laravel-boost-mcp.sh
```

### 2. Configure your MCP client

#### Windsurf

Edit `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "/Users/<you>/.codeium/laravel-boost-mcp.sh"
    }
  }
}
```

> **Note:** Use the full absolute path — Windsurf does not expand `~`. Windsurf launches MCP servers with `$PWD` set to your open workspace, so the script finds the project automatically. One entry works for every Laravel project you open.

#### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "laravel-boost": {
      "command": "/Users/<you>/.codeium/laravel-boost-mcp.sh"
    }
  }
}
```

#### Claude Code

```bash
claude mcp add -s user -t stdio laravel-boost ~/.codeium/laravel-boost-mcp.sh
```

### 3. Restart your MCP client

- **Windsurf**: Settings → MCP / Tools → Refresh
- **Claude Code**: Restart the session
- **Cursor**: Restart the editor

## How It Works

### Project detection

The script takes an optional path argument. If none is given, it uses `$PWD` (which MCP clients set to the open workspace). It then walks up the directory tree until it finds `artisan`.

### Execution method (priority order)

1. **Sail** — `vendor/bin/sail` or `sail` in `$PATH`
2. **Docker Compose** — `docker-compose.yml` / `compose.yml` present (service defaults to `laravel.test`, override with `DOCKER_SERVICE` env var)
3. **Local PHP** — fallback

### Health check

```bash
~/.codeium/laravel-boost-mcp.sh --check /path/to/project
# or cd into a project and run:
~/.codeium/laravel-boost-mcp.sh --check
```

```
boost-mcp: check
  project_dir  : /Users/you/Projects/my-app
  artisan_dir  : /Users/you/Projects/my-app
  exec_method  : sail
  sail_bin     : /Users/you/Projects/my-app/vendor/bin/sail
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `artisan not found` | Make sure your project is open in the IDE, or pass the path as an argument |
| `Boost not installed` | `sail composer require laravel/boost --dev` |
| MCP connects but tools fail | Check `.env` and database config inside the container |
| Windsurf "cannot initialise server" | Use the **full absolute path** to the script (no `~`). Check you're editing the right config file. |
| Wrong Docker service | Set `"DOCKER_SERVICE": "my-service"` in the `env` block of your MCP config |

## License

MIT
