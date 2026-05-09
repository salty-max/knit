const core = @import("core");
const char_mod = @import("char.zig");

/// Match any single UTF-8 codepoint at the cursor.
///
/// Example:
/// ```zig
/// const ac = comptime anyChar();
/// // ac.run("☃ snowman", alloc) → ok = .{ .value = '☃', .index = 3 } (3-byte)
/// ```
pub fn anyChar() core.Parser(u21) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| return char_mod.decodeErrorToParseError(err, state.index, "anyChar", null);
            state.advance(decoded.width);
            return core.ok(decoded.cp, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
