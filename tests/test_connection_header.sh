#!/usr/bin/env bash
# The server closes the socket after writing each response, so it must not
# advertise "Connection: keep-alive". The header has to match the real
# behaviour, which is "close".
source "$(dirname "$0")/lib.sh"

docroot="$(mktemp -d)"
echo "hello" > "$docroot/hello.txt"

build_server
start_server "$docroot" || exit 1

conn="$(curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/hello.txt" \
        | awk 'tolower($1) == "connection:" { print tolower($2) }' | tr -d '\r')"

stop_server

[ "$conn" = "close" ] && ok "advertises Connection: close" || bad "expected 'close', got '$conn'"
finish
