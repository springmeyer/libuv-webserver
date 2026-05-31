# Shared helpers for webserver integration tests.
# Source this from a test script, then use start_server/stop_server and the
# ok/bad assertion helpers, ending with `finish`.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
SERVER_BIN="$BUILD_DIR/webserver"
export PORT="${PORT:-8000}"
SERVER_PID=""
SERVER_LOG=""

build_server() {
  cmake --build "$BUILD_DIR" --target webserver >/dev/null
}

# start_server <docroot>: run the server with its working directory set to
# <docroot> (the server serves files relative to its CWD) and wait until it is
# listening.
start_server() {
  local docroot="$1"
  local existing
  existing="$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    kill -TERM $existing 2>/dev/null || true
    sleep 0.5
  fi
  SERVER_LOG="$(mktemp)"
  ( cd "$docroot" && exec "$SERVER_BIN" ) >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  local i
  for i in $(seq 1 50); do
    if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "server died during startup:"
      cat "$SERVER_LOG"
      return 1
    fi
    sleep 0.2
  done
  echo "server never started listening on port $PORT"
  return 1
}

stop_server() {
  [ -n "$SERVER_PID" ] && kill -TERM "$SERVER_PID" 2>/dev/null
  wait "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
}

PASS=0
FAIL=0
ok()  { echo "  ok:   $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
finish() {
  echo "---- passed=$PASS failed=$FAIL ----"
  [ "$FAIL" -eq 0 ]
}
