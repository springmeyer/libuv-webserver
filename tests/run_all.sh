#!/usr/bin/env bash
# Run every webserver/webclient integration test. Exits non-zero if any fail.
cd "$(dirname "$0")"
fail=0
for t in test_*.sh; do
  echo "== $t =="
  if bash "$t"; then :; else fail=1; fi
  echo
done
[ "$fail" -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$fail"
