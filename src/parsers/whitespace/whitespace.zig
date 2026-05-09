const core = @import("core");
const internal = @import("internal.zig");

/// Match zero-or-more contiguous ASCII whitespace bytes (space, tab,
/// `\n`, `\r`) and return the matched byte slice borrowed from the
/// input. The slice's lifetime is the input's — `whitespace`
/// allocates nothing.
///
/// **Always succeeds.** On empty input or a non-whitespace cursor
/// position, returns an empty slice and leaves the cursor unchanged.
/// Tabs and CRLF byte pairs are preserved verbatim in the slice.
///
/// Use as an optional skip in larger grammars (e.g. between tokens).
/// For "must have at least one space here", reach for `whitespace1`.
///
/// Example:
/// ```zig
/// const ws = comptime whitespace();
/// // ws.run("  hi", alloc) → ok = .{ .value = "  ", .index = 2 }
/// // ws.run("", alloc)     → ok = .{ .value = "", .index = 0 }
/// // ws.run("xy", alloc)   → ok = .{ .value = "", .index = 0 }
/// ```
pub fn whitespace() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            const start = state.index;
            internal.scanWhitespace(state);
            return core.ok(state.input[start..state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
