const core = @import("core");

/// Codepoint-aware variant of `everythingUntil`. Same semantics —
/// consume until `stopP` would succeed at the cursor, returning
/// the borrowed slice and leaving the cursor at the start of
/// `stopP`'s match — but advances by full UTF-8 codepoint width
/// per iteration instead of one byte.
///
/// Use this when the input is UTF-8 text and the byte-level
/// advance of `everythingUntil` could land mid-codepoint (which
/// would still produce a valid byte slice, but the cursor would
/// no longer be on a codepoint boundary).
///
/// Three failure shapes:
/// - **Hit EOF** without `stopP` matching → `.incomplete`
/// - **Invalid UTF-8 leading byte** before `stopP` matches → `.lexical`
/// - **Truncated UTF-8** sequence before `stopP` matches → `.incomplete`
///
/// **Perf.** Zero allocation for the consumed slice (borrowed).
/// One UTF-8 decode plus one `stopP` attempt per iteration.
///
/// Example:
/// ```zig
/// const body = comptime everyCharUntil(char(']'));
/// // body.run("café]rest", a) → ok = .{ .value = "café", .index = 5 }
/// // body.run("abcXY",     a) → err: hit EOF before ']' matched
/// ```
pub fn everyCharUntil(comptime stopP: anytype) core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            const start = state.index;
            while (true) {
                const saved = state.index;
                const r = stopP.parseFn(state);
                state.index = saved;
                if (r == .ok) {
                    return core.ok(state.input[start..state.index], state.index);
                }
                const decoded = core.decodeNext(state) catch |err| switch (err) {
                    error.UnexpectedEof => return .{ .err = core.parseError("everyCharUntil", state.index, "expected stop pattern before end of input", .{
                        .kind = .incomplete,
                    }) },
                    error.Utf8Invalid => return .{ .err = core.parseError("everyCharUntil", state.index, "invalid UTF-8 before stop pattern", .{
                        .kind = .lexical,
                    }) },
                    error.Utf8Truncated => return .{ .err = core.parseError("everyCharUntil", state.index, "truncated UTF-8 before stop pattern", .{
                        .kind = .incomplete,
                    }) },
                };
                state.advance(decoded.width);
            }
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
