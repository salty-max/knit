const core = @import("core");
const internal = @import("internal.zig");

/// Match one-or-more contiguous ASCII whitespace bytes (space, tab,
/// `\n`, `\r`) and return the matched byte slice borrowed from the
/// input. The slice's lifetime is the input's — `whitespace1`
/// allocates nothing.
///
/// Failure modes:
/// - Empty input at cursor: `kind = .incomplete`.
/// - First byte is not whitespace: `kind = .syntactic`, cursor unchanged.
///
/// Use to require at least one whitespace byte (e.g. between two
/// adjacent tokens that mustn't merge).
///
/// Example:
/// ```zig
/// const ws1 = comptime whitespace1();
/// // ws1.run("  hi", alloc) → ok = .{ .value = "  ", .index = 2 }
/// // ws1.run("xy", alloc)   → err with parser = "whitespace1", cursor 0
/// // ws1.run("", alloc)     → err with kind = .incomplete
/// ```
pub fn whitespace1() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("whitespace1", state.index, "unexpected end of input", .{
                    .expected = "whitespace",
                    .kind = .incomplete,
                }) };
            }
            const start = state.index;
            internal.scanWhitespace(state);
            if (state.index == start) {
                return .{ .err = core.parseError("whitespace1", state.index, "expected one or more whitespace bytes", .{
                    .expected = "whitespace",
                    .kind = .syntactic,
                }) };
            }
            return core.ok(state.input[start..state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
