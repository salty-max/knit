#!/usr/bin/env bash
# check-strict.sh — strict-compiler bans, mirroring CLAUDE.md's
# "Strict Compiler Configuration" / "Forbidden in src/" section.
#
# Rules (each can be silenced by `// allow-strict: <reason>` directly above):
#   1. `anyerror` in any code line (not pure comment)
#   2. `*anyopaque` (or `*const anyopaque`) anywhere in src/
#   3. `@as(`            requires `// @as: <reason>` on the line above
#   4. `@ptrCast(` / `@alignCast(` / `@bitCast(` require `// safety: <reason>` above
#   5. `unreachable` (as a statement) requires a justifying `//` comment above
#   6. `@compileError("TODO"` requires a justifying `//` comment above
#   7. `std.debug.print(` anywhere in src/ (no allowlist; use parsers/util/debugLog)
#
# Usage:
#   bash scripts/check-strict.sh                 # walk every .zig in src/
#   bash scripts/check-strict.sh f1.zig f2.zig   # check only listed files
#                                                  (lefthook with {staged_files})
set -e

violations=0
report() {
  local file="$1" line="$2" rule="$3" content="$4"
  echo "  $file:$line: [$rule] $content"
  violations=$((violations + 1))
}

trim() { echo "$1" | awk '{$1=$1};1'; }

# Returns 0 (true) if the comment line silences the violation.
is_allowed() {
  local prev="$1"
  case "$prev" in
    *"allow-strict:"*) return 0 ;;
  esac
  return 1
}

# Returns 0 if `prev` matches the per-rule justification comment.
has_justification() {
  local prev="$1" needle="$2"
  case "$prev" in
    *"$needle"*) return 0 ;;
  esac
  return 1
}

# Returns 0 if line is a pure comment ("// ..." with optional leading whitespace).
is_pure_comment() {
  local trimmed
  trimmed=$(trim "$1")
  [[ "$trimmed" == //* ]]
}

scan_file() {
  local file="$1"
  [[ -f "$file" && "$file" == *.zig ]] || return 0
  # `src/`-only enforcement; tests/ is allowed to use whatever.
  case "$file" in
    src/*) ;;
    *) return 0 ;;
  esac

  local prev=""
  local lineno=0
  local stripped
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    stripped=$(trim "$line")

    # Rule 1: anyerror in code (skip pure comment lines).
    if [[ "$stripped" != "//"* ]] && [[ "$line" == *"anyerror"* ]]; then
      if ! is_allowed "$prev"; then
        report "$file" "$lineno" "anyerror" "$line"
      fi
    fi

    # Rule 2: *anyopaque (or *const anyopaque) anywhere in src/.
    # The Parser(T) design uses comptime-monomorphic fn pointers; no
    # type-erasure context is needed.
    if [[ "$stripped" != "//"* ]] \
        && [[ "$line" == *"*anyopaque"* || "$line" == *"*const anyopaque"* ]]; then
      if ! is_allowed "$prev"; then
        report "$file" "$lineno" "anyopaque-banned" "$line"
      fi
    fi

    # Rule 3: @as(.
    if [[ "$line" == *"@as("* ]] && [[ "$stripped" != "//"* ]]; then
      if ! is_allowed "$prev" && ! has_justification "$prev" "@as:"; then
        report "$file" "$lineno" "@as-no-comment" "$line"
      fi
    fi

    # Rule 4: @ptrCast / @alignCast / @bitCast.
    for cast in "@ptrCast(" "@alignCast(" "@bitCast("; do
      if [[ "$line" == *"$cast"* ]] && [[ "$stripped" != "//"* ]]; then
        if ! is_allowed "$prev" && ! has_justification "$prev" "safety:"; then
          report "$file" "$lineno" "${cast%(}-no-safety-comment" "$line"
        fi
        break
      fi
    done

    # Rule 5: unreachable (as a statement). Word-boundary via grep -w
    # because bash regex `\b` is not portable across platforms.
    if [[ "$stripped" != "//"* ]] && echo "$line" | grep -qw "unreachable"; then
      if ! is_allowed "$prev" && [[ "$prev" != *"//"* ]]; then
        report "$file" "$lineno" "unreachable-no-comment" "$line"
      fi
    fi

    # Rule 6: @compileError("TODO".
    if [[ "$line" == *'@compileError("TODO'* ]] && [[ "$stripped" != "//"* ]]; then
      if ! is_allowed "$prev" && [[ "$prev" != *"//"* ]]; then
        report "$file" "$lineno" "compileError-TODO" "$line"
      fi
    fi

    # Rule 7: std.debug.print( in src/ (no allowlist).
    if [[ "$line" == *"std.debug.print("* ]] && [[ "$stripped" != "//"* ]]; then
      report "$file" "$lineno" "std.debug.print-in-src" "$line"
    fi

    prev="$line"
  done < "$file"
}

if [[ $# -eq 0 ]]; then
  while IFS= read -r -d '' file; do
    scan_file "$file"
  done < <(find src -type f -name "*.zig" -print0 2>/dev/null)
else
  for file in "$@"; do
    scan_file "$file"
  done
fi

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "❌ $violations strict-compiler violation(s) found." >&2
  echo "   Allowlist a violation with '// allow-strict: <reason>' on the line above." >&2
  echo "   Or supply the per-rule justification: '// @as: ...' or '// safety: ...'." >&2
  echo "   See CLAUDE.md \"Strict Compiler Configuration\"." >&2
  exit 1
fi
