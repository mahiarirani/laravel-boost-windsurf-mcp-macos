#!/bin/bash

# Laravel Boost MCP — Sail / Docker Compose Bridge
#
# Install:
#   cp init.sh ~/.codeium/laravel-boost-mcp.sh
#   chmod +x ~/.codeium/laravel-boost-mcp.sh

LOG="$HOME/.codeium/laravel-boost-mcp.log"

debug_log() {
  echo "[$(date '+%H:%M:%S')] $1" >> "$LOG"
  echo "[BOOST-MCP] $1" >&2
}

debug_log "Starting launcher (PWD=$PWD, args=$*)"

# --- Walk up to find artisan --------------------------------------------------

find_artisan_up() {
  local dir="$1"
  while [ "$dir" != "/" ] && [ "$dir" != "" ]; do
    if [ -f "$dir/artisan" ]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# --- Find active Windsurf project (macOS) -------------------------------------

find_windsurf_project() {
  debug_log "Looking for active Windsurf project..."

  # Priority 1: BOOST_WORKSPACE env var
  if [ -n "${BOOST_WORKSPACE:-}" ] && [ -f "$BOOST_WORKSPACE/artisan" ]; then
    debug_log "Using BOOST_WORKSPACE: $BOOST_WORKSPACE"
    echo "$BOOST_WORKSPACE"
    return 0
  fi

  # Priority 2: Explicit argument
  if [ -n "${1:-}" ] && [ -d "${1:-}" ]; then
    local from_arg
    from_arg=$(find_artisan_up "$1" 2>/dev/null) && {
      debug_log "Using argument: $from_arg"
      echo "$from_arg"
      return 0
    }
  fi

  # Priority 3: PWD
  local from_pwd
  from_pwd=$(find_artisan_up "$PWD" 2>/dev/null) && {
    debug_log "Using PWD: $from_pwd"
    echo "$from_pwd"
    return 0
  }

  # Priority 4: Windsurf process cwd via lsof (macOS)
  debug_log "Checking Windsurf process working directories..."
  local windsurf_pids
  windsurf_pids=$(pgrep -f "[Ww]indsurf" 2>/dev/null || true)
  for pid in $windsurf_pids; do
    local cwd
    cwd=$(lsof -p "$pid" -Fn 2>/dev/null | grep '^n/' | grep 'cwd' -A1 | tail -1 | sed 's/^n//' || true)
    if [ -z "$cwd" ]; then
      # Alternative: try lsof cwd directly
      cwd=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | grep '^n/' | head -1 | sed 's/^n//' || true)
    fi
    if [ -n "$cwd" ] && [ -d "$cwd" ]; then
      debug_log "Found Windsurf pid $pid cwd: $cwd"
      local from_proc
      from_proc=$(find_artisan_up "$cwd" 2>/dev/null) && {
        debug_log "Using Windsurf process dir: $from_proc"
        echo "$from_proc"
        return 0
      }
    fi
  done

  # Priority 5: Windsurf code_tracker files
  debug_log "Checking Windsurf code_tracker..."
  local tracker_dir="$HOME/.codeium/windsurf/code_tracker/active"
  if [ -d "$tracker_dir" ]; then
    local candidate
    # Extract file:/// URIs from tracker JSON files, most recent first
    for f in $(ls -t "$tracker_dir"/*.json 2>/dev/null); do
      while IFS= read -r candidate; do
        [ -z "$candidate" ] && continue
        if [ -d "$candidate" ]; then
          debug_log "Tracker candidate: $candidate"
          local from_tracker
          from_tracker=$(find_artisan_up "$candidate" 2>/dev/null) && {
            debug_log "Using code_tracker: $from_tracker"
            echo "$from_tracker"
            return 0
          }
        fi
      done < <(grep -oE 'file:///[^"]+' "$f" 2>/dev/null | sed 's|file://||' | sort -u)
    done
  fi

  # Priority 6: Most recently modified Laravel project in common dirs
  debug_log "Scanning for recently modified Laravel projects..."
  local most_recent_dir=""
  local most_recent_time=0
  local search_dirs=("$HOME/Projects" "$HOME/Code" "$HOME/Sites" "$HOME/Desktop")

  for search_dir in "${search_dirs[@]}"; do
    [ -d "$search_dir" ] || continue
    for dir in "$search_dir"/*/; do
      if [ -f "$dir/artisan" ]; then
        # macOS stat: -f %m for modification time
        local mtime
        mtime=$(stat -f %m "$dir/artisan" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$most_recent_time" ]; then
          most_recent_time="$mtime"
          most_recent_dir="$dir"
        fi
      fi
    done
  done

  if [ -n "$most_recent_dir" ]; then
    local current_time
    current_time=$(date +%s)
    local time_diff=$((current_time - most_recent_time))
    if [ "$time_diff" -lt 3600 ]; then
      debug_log "Using most recent project (${time_diff}s ago): $most_recent_dir"
      echo "$most_recent_dir"
      return 0
    else
      debug_log "Most recent project too old (${time_diff}s ago): $most_recent_dir"
    fi
  fi

  debug_log "No active Laravel project found"
  return 1
}

# --- Main ---------------------------------------------------------------------

PROJECT_DIR=$(find_windsurf_project "${1:-}" || true)

if [ -z "$PROJECT_DIR" ] || [ ! -f "$PROJECT_DIR/artisan" ]; then
  debug_log "FAIL: Could not find a Laravel project"
  echo "Error: Could not find Laravel project directory." >&2
  echo "Set BOOST_WORKSPACE env var in your MCP config." >&2
  echo "Debug log: $LOG" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR/vendor/laravel/boost" ]; then
  debug_log "FAIL: Boost not installed at $PROJECT_DIR"
  echo "Error: Boost not installed. Run: composer require laravel/boost --dev" >&2
  exit 1
fi

debug_log "Project: $PROJECT_DIR"

# --- Pick runner: sail > docker compose > php ---------------------------------

cd "$PROJECT_DIR"

if [ -x "$PROJECT_DIR/vendor/bin/sail" ]; then
  debug_log "Launching via Sail"
  exec "$PROJECT_DIR/vendor/bin/sail" artisan boost:mcp
elif command -v sail >/dev/null 2>&1; then
  debug_log "Launching via Sail (PATH)"
  exec sail artisan boost:mcp
elif command -v docker >/dev/null 2>&1 && [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  local_dc=""
  docker compose version >/dev/null 2>&1 && local_dc="docker compose"
  [ -z "$local_dc" ] && command -v docker-compose >/dev/null 2>&1 && local_dc="docker-compose"
  if [ -n "$local_dc" ]; then
    debug_log "Launching via $local_dc"
    exec $local_dc exec -T "${DOCKER_SERVICE:-laravel.test}" php artisan boost:mcp
  fi
fi

debug_log "Launching via local PHP"
exec php artisan boost:mcp
