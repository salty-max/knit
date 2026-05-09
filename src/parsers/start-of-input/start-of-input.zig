const core = @import("core");

/// Assert the cursor is at the start of input. `ok({}, 0)` if
/// `state.index == 0`; otherwise an err whose `index` reports the
/// current cursor position (the violation point). Symmetric
/// counterpart to `endOfInput`.
///
/// **Perf:** O(1) cursor check, zero allocation. The err carries
/// no `actual` slice — the violating position is captured in
/// `err.index`, and there's no input prefix to preview meaningfully
/// (the leftover IS the entire input — and the caller already has
/// the input).
///
/// Useful inside `lookAhead`, `chain`, or composed grammars where a
/// child parser needs to verify it was invoked before any
/// consumption — e.g. a top-level directive that must be the very
/// first thing in the file:
///
/// ```zig
/// const shebang = comptime startOfInput().then(str("#!"));
/// // shebang.run("#!/bin/sh\n", a) → ok = .{ .value = "#!", .index = 2 }
/// ```
pub fn startOfInput() core.Parser(void) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(void) {
            if (state.index == 0) {
                return .{ .ok = .{ .value = {}, .index = 0 } };
            }
            return .{ .err = core.parseError("startOfInput", state.index, "expected start of input", .{
                .kind = .syntactic,
            }) };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
