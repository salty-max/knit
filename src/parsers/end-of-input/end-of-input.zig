const core = @import("core");

/// Maximum bytes of leftover input shown in `actual` when the
/// assertion fails. Keeps diagnostics readable on long inputs.
const max_preview_bytes: usize = 16;

/// Assert the cursor is at end-of-input. `ok({}, index)` if
/// `state.index >= state.input.len`; otherwise an err whose
/// `actual` borrows the leftover prefix (capped at 16 bytes for
/// readability) directly from `state.input`. Zero allocation.
///
/// **UTF-8 truncation caveat.** The 16-byte cap is byte-level, so
/// the preview can end mid-codepoint and contain invalid UTF-8.
/// `formatParseErrorPretty` prints `actual` verbatim — consumers
/// that render to a strict UI should validate or sanitize first.
///
/// Common pattern — assert the entire input was consumed:
///
/// ```zig
/// const number = comptime digits().skip(endOfInput());
/// // number.run("42",  a) → ok = .{ .value = "42", .index = 2 }
/// // number.run("42x", a) → err with parser = "endOfInput", actual = "x"
/// ```
///
/// Returns `Parser(void)` — the carrier-only signal: consumers
/// chain it with `.skip` for the assertion or pattern-match on
/// `result == .ok` directly.
pub fn endOfInput() core.Parser(void) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(void) {
            if (state.index >= state.input.len) {
                return .{ .ok = .{ .value = {}, .index = state.index } };
            }
            const remaining = state.input[state.index..];
            const preview_len = @min(remaining.len, max_preview_bytes);
            return .{ .err = core.parseError("endOfInput", state.index, "expected end of input", .{
                .actual = remaining[0..preview_len],
                .kind = .syntactic,
            }) };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
