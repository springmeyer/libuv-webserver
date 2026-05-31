#!/usr/bin/env bash
# An empty file must return 200 with an empty body. The buggy version reads
# with fread(ptr, size, 1, f), which returns 0 for a zero-byte file and was
# mistaken for a read failure, producing 500.
source "$(dirname "$0")/lib.sh"

docroot="$(mktemp -d)"
: > "$docroot/empty.txt"

build_server
start_server "$docroot" || exit 1

code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/empty.txt")"
len="$(curl -s -D - -o /dev/null "http://127.0.0.1:$PORT/empty.txt" \
       | awk 'tolower($1) == "content-length:" { print $2 }' | tr -d '\r')"

stop_server

[ "$code" = "200" ] && ok "empty file returns 200" || bad "expected 200, got $code"
[ "$len" = "0" ]    && ok "empty file content-length is 0" || bad "expected content-length 0, got '$len'"
finish
