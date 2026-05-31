# Helper for sanitizer-based tests. Sourced after lib.sh.
# Configures (once) and builds an AddressSanitizer build of the server, then
# points SERVER_BIN at it. Reused across runs via the build-asan/ directory.
#
# These tests catch memory bugs that do not surface as wrong HTTP responses on
# loopback (use-after-free, leaks), so the "red" comes from the sanitizer
# rather than from an observable response difference.

ASAN_BUILD_DIR="${ASAN_BUILD_DIR:-$ROOT/build-asan}"

build_asan_server() {
  if [ ! -f "$ASAN_BUILD_DIR/CMakeCache.txt" ]; then
    cmake -S "$ROOT" -B "$ASAN_BUILD_DIR" -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" \
      -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" \
      -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address" >/dev/null
  fi
  cmake --build "$ASAN_BUILD_DIR" --target webserver >/dev/null
  SERVER_BIN="$ASAN_BUILD_DIR/webserver"
}

# Fail the current test if the server log shows an AddressSanitizer error.
assert_no_asan_error() { # $1 = description
  if grep -qiE "ERROR: AddressSanitizer|use-after-free|heap-buffer-overflow|detected memory leaks" "$SERVER_LOG"; then
    bad "$1"
    grep -iE "ERROR: AddressSanitizer|SUMMARY: AddressSanitizer" "$SERVER_LOG" | head -2 | sed 's/^/      /'
  else
    ok "$1"
  fi
}
