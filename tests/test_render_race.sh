#!/usr/bin/env bash
# on_message_complete queues render() on the thread pool, which dereferences
# the client. If the peer closes right after sending the request, on_read sees
# EOF and uv_close -> on_close deletes the client while render (or after_render)
# is still using it: a use-after-free.
#
# Trigger: open many connections, send a full request for a large file (so
# render spends time reading it), then close immediately without reading the
# response. Caught by AddressSanitizer.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib_asan.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "  skip: python3 needed to drive the race trigger"
  finish
  exit 0
fi

docroot="$(mktemp -d)"
# Big enough that render() is still reading the file when the close arrives.
dd if=/dev/urandom of="$docroot/big.bin" bs=1m count=16 2>/dev/null

build_asan_server
export ASAN_OPTIONS="abort_on_error=0:exitcode=0"
start_server "$docroot" || exit 1

python3 - <<'PY'
import socket, threading
def hit():
    try:
        s = socket.create_connection(("127.0.0.1", 8000))
        s.sendall(b"GET /big.bin HTTP/1.1\r\nHost: x\r\n\r\n")
        s.close()            # close immediately, while render is queued/running
    except OSError:
        pass
for _ in range(8):
    ts = [threading.Thread(target=hit) for _ in range(40)]
    for t in ts: t.start()
    for t in ts: t.join()
PY
sleep 1
stop_server

assert_no_asan_error "closing a connection during render does not free the client in use"
finish
