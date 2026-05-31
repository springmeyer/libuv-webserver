#!/usr/bin/env bash
# after_render built the response into a stack-local std::string and handed
# its buffer to the async uv_write. For a large file that buffer is heap
# allocated and freed when after_render returns, before libuv flushes the
# deferred write, so uv__writev reads freed memory.
#
# The corruption does not surface as a wrong response on loopback, so the red
# is an AddressSanitizer heap-use-after-free while serving a large file.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib_asan.sh"

docroot="$(mktemp -d)"
# Larger than the socket send buffer so the write is deferred past the return
# of after_render.
dd if=/dev/urandom of="$docroot/big.bin" bs=1m count=8 2>/dev/null
orig="$(shasum -a256 "$docroot/big.bin" | awk '{print $1}')"

build_asan_server
export ASAN_OPTIONS="abort_on_error=0:exitcode=0"
start_server "$docroot" || exit 1

corrupt=0
for n in 1 2 3 4 5; do
  got="$(curl -s "http://127.0.0.1:$PORT/big.bin" | shasum -a256 | awk '{print $1}')"
  [ "$got" = "$orig" ] || corrupt=1
done
sleep 1
stop_server

assert_no_asan_error "serving a large file does not use freed write buffers"
[ "$corrupt" -eq 0 ] && ok "large file served intact across 5 requests" || bad "large file body was corrupted"
finish
