#!/usr/bin/env bash
# A request whose path escapes the document root with ".." must be rejected.
# The buggy version appends the raw URL path to ".", so "/../secret.txt"
# reads a file above the served directory.
source "$(dirname "$0")/lib.sh"

base="$(mktemp -d)"
docroot="$base/pub"
mkdir -p "$docroot"
echo "TOP-SECRET" > "$base/secret.txt"

build_server
start_server "$docroot" || exit 1

code="$(curl -s --path-as-is -o /tmp/trav_body -w '%{http_code}' "http://127.0.0.1:$PORT/../secret.txt")"
body="$(cat /tmp/trav_body)"

stop_server

[ "$code" = "403" ] && ok "traversal rejected with 403" || bad "expected 403, got $code"
case "$body" in
  *TOP-SECRET*) bad "secret file contents leaked through traversal" ;;
  *)            ok "secret contents not leaked" ;;
esac
finish
