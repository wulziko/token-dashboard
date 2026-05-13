#!/usr/bin/env bash
# tokendash.sh — start / stop / status / rescan the Token Dashboard launchd agent.
# Usage: tokendash {start|stop|restart|status|rescan|url}

set -e

LABEL="com.margi.token-dashboard"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
URL="http://127.0.0.1:8080"
DASH_DIR="/Users/guymargi/Claude Code/token-dashboard"

if [ ! -f "$PLIST" ]; then
  echo "ERROR: launchd plist missing at $PLIST"
  exit 1
fi

is_loaded() {
  launchctl list | grep -q "$LABEL"
}

is_running() {
  curl -sS -o /dev/null -w "%{http_code}" --max-time 2 "$URL/api/overview" 2>/dev/null | grep -q 200
}

case "${1:-status}" in
  start)
    if is_running; then
      echo "Token Dashboard already running at $URL"
      exit 0
    fi
    if ! is_loaded; then
      launchctl load "$PLIST" 2>/dev/null || true
    fi
    launchctl kickstart -k "gui/$(id -u)/${LABEL}"
    echo -n "Starting"
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if is_running; then echo; echo "Ready at $URL"; exit 0; fi
      echo -n "."; sleep 1
    done
    echo; echo "Did not come up within 10s. Check logs:"
    echo "  tail $HOME/Library/Logs/token-dashboard.err"
    exit 1
    ;;
  stop)
    if is_loaded; then
      launchctl unload "$PLIST" 2>/dev/null || true
    fi
    # belt-and-braces — kill any stragglers
    pkill -f "cli.py dashboard" 2>/dev/null || true
    echo "Token Dashboard stopped"
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  status)
    if is_running; then
      echo "RUNNING at $URL"
      curl -sS "$URL/api/overview" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"  sessions: {d.get('sessions')}  input: {d.get('input_tokens'):,}  output: {d.get('output_tokens'):,}  cache_read: {d.get('cache_read_tokens'):,}\")" 2>/dev/null || true
    elif is_loaded; then
      echo "LOADED but not responding — may be starting or crashed. Check: tail $HOME/Library/Logs/token-dashboard.err"
    else
      echo "STOPPED"
    fi
    ;;
  rescan)
    cd "$DASH_DIR" && python3 cli.py scan
    ;;
  url)
    echo "$URL"
    ;;
  *)
    echo "Usage: tokendash {start|stop|restart|status|rescan|url}"
    exit 1
    ;;
esac
