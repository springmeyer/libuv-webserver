#!/usr/bin/env bash
# after_write skipped "delete closure" when the handle was already closing, so
# a render_baton (and its whole response body) leaked whenever a client hung up
# while its write was still queued.
#
# There is no observable HTTP symptom, so this checks the live heap with the
# macOS `leaks` tool. The trigger reads one byte (so render has finished and is
# not in flight) then half-closes with a FIN while a large write is still
# pending, which makes the server uv_close the handle and cancel the write.
source "$(dirname "$0")/lib.sh"

if ! command -v leaks >/dev/null 2>&1; then
  echo "  skip: macOS 'leaks' tool not available on this platform"
  finish
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "  skip: python3 needed to drive the half-close trigger"
  finish
  exit 0
fi

docroot="$(mktemp -d)"
# Large enough that the write stays queued when the client stops reading.
dd if=/dev/urandom of="$docroot/big.bin" bs=1m count=64 2>/dev/null

build_server
start_server "$docroot" || exit 1

python3 - <<'PY'
import socket, time
socks = []
for _ in range(25):
    s = socket.create_connection(("127.0.0.1", 8000))
    s.sendall(b"GET /big.bin HTTP/1.1\r\nHost: x\r\n\r\n")
    s.recv(1)                    # render done; large write now pending
    s.shutdown(socket.SHUT_WR)   # FIN without RST -> server uv_close cancels the write
    socks.append(s)              # keep the socket so no RST is sent
    time.sleep(0.02)
time.sleep(1)
PY

# "Process <pid>: <N> leaks for <M> total leaked bytes."
count="$(leaks "$SERVER_PID" 2>/dev/null | awk '/leaks for/ { print $3 }')"
stop_server

[ "${count:-unknown}" = "0" ] && ok "no render_baton leaked after client hang-up (leaks=$count)" \
                               || bad "render_baton leaked: $count blocks still allocated"
finish
