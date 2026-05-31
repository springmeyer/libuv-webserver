#!/usr/bin/env bash
# Smoke test for webclient. It opens 100 keep-alive connections, writes a
# request, reads the response and closes. This exercises the request-buffer
# lifetime fix (the request now lives in the client, not on the stack) and the
# normal status>=0 resolve path.
#
# Note: there is no behavioral red here. The request is tiny and is written
# synchronously, so the old stack-buffer use-after-free did not corrupt output;
# the resolve-failure NULL deref needs a hostname the binary hard-codes to
# "localhost". The fixes are hardening, and this test guards against a crash or
# hang regression.
source "$(dirname "$0")/lib.sh"

cmake --build "$BUILD_DIR" --target webclient >/dev/null
CLIENT_BIN="$BUILD_DIR/webclient"

docroot="$(mktemp -d)"
echo "hi" > "$docroot/hello"

build_server
start_server "$docroot" || exit 1

# The client connects to localhost:8000, runs its batch, and exits on its own.
if ( ulimit -t 20; "$CLIENT_BIN" >/tmp/webclient_smoke.log 2>&1 ); then
  ok "webclient ran to completion without crashing"
else
  bad "webclient exited non-zero ($?)"
  sed 's/^/      /' /tmp/webclient_smoke.log | tail -5
fi

stop_server
finish
