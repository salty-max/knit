const core = @import("core");

/// Consume bytes until `stopP` would succeed at the cursor.
/// Returns the consumed slice (borrowed from `state.input`); the
/// cursor lands at the start of `stopP`'s match — `stopP` itself
/// is NOT consumed. Reach EOF without `stopP` matching → err.
///
/// Byte-level: advances 1 byte per iteration. Use `everyCharUntil`
/// for codepoint-aware advance (UTF-8).
///
/// **Perf.** Zero allocation for the consumed slice (borrowed).
/// However, `stopP` is run at every position — for input of length
/// N where the match is at the end, that's N attempts. If `stopP`
/// allocates on err (current parsil-zig parsers don't, but custom
/// ones might), each failed attempt pays one alloc; combine with
/// the canonical arena-per-parse for cleanup.
///
/// Example:
/// ```zig
/// const body = comptime everythingUntil(char(']'));
/// // body.run("abc]xyz", a) → ok = .{ .value = "abc", .index = 3 }
/// // body.run("abcXY",  a) → err: hit EOF before ']' matched
/// ```
pub fn everythingUntil(comptime stopP: anytype) core.Parser([]const u8) {
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
                if (state.index >= state.input.len) {
                    return .{ .err = core.parseError("everythingUntil", state.index, "expected stop pattern before end of input", .{
                        .kind = .incomplete,
                    }) };
                }
                state.advance(1);
            }
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
