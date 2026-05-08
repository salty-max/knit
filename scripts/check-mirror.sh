#!/usr/bin/env bash
# check-mirror.sh — enforce src/parsers ↔ tests/parsers mirror layout.
#
# Rule: every src/parsers/<path>.zig must have a matching
# tests/parsers/<path with .test.zig suffix>.zig, and vice versa.
#
# Exempt from the src→test direction:
#   - src/parsil.zig             (public barrel; just re-exports)
#   - src/core.zig               (covered by tests when Phase 1 lands)
#   - src/util/**/*.zig          (covered by their consumers' tests)
#
# Whole-tree only — a missing mirror is by nature a whole-tree property.
set -e

ROOT="${ROOT:-.}"
violations=0

# Files whose mirror test isn't required (yet).
is_exempt() {
  local file="$1"
  case "$file" in
    src/parsil.zig|./src/parsil.zig) return 0 ;;
    src/core.zig|./src/core.zig)     return 0 ;;
    src/util/*|./src/util/*)         return 0 ;;
  esac
  return 1
}

# Direction 1: every src/parsers/**/*.zig has a tests/parsers/**/*.test.zig
while IFS= read -r -d '' src_file; do
  rel="${src_file#$ROOT/}"
  rel="${rel#./}"
  test_file="${rel/#src\//tests/}"
  test_file="${test_file%.zig}.test.zig"
  if [[ ! -f "$ROOT/$test_file" ]]; then
    if ! is_exempt "$rel"; then
      echo "  src has no test mirror: $rel → expected $test_file"
      violations=$((violations + 1))
    fi
  fi
done < <(find "$ROOT/src/parsers" -type f -name "*.zig" -print0 2>/dev/null)

# Direction 2: every tests/**/*.test.zig has a src/**/*.zig
while IFS= read -r -d '' test_file; do
  rel="${test_file#$ROOT/}"
  rel="${rel#./}"
  # tests/util.zig is the helper, not a mirror test
  case "$rel" in
    tests/util.zig|tests/util.test.zig) continue ;;
  esac
  src_file="${rel/#tests\//src/}"
  src_file="${src_file%.test.zig}.zig"
  if [[ ! -f "$ROOT/$src_file" ]]; then
    echo "  test has no src mirror (orphan): $rel → expected $src_file"
    violations=$((violations + 1))
  fi
done < <(find "$ROOT/tests" -type f -name "*.test.zig" -print0 2>/dev/null)

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "❌ $violations mirror violation(s) found." >&2
  echo "   Convention: src/parsers/<path>.zig ↔ tests/parsers/<path>.test.zig" >&2
  echo "   See CLAUDE.md \"Source Layout\"." >&2
  exit 1
fi
