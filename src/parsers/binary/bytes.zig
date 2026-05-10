const core = @import("core");

/// Read exactly `n` raw bytes at the cursor; return as a
/// borrowed `[]const u8` slice into `state.input`. Cursor
/// advances by `n` bytes. EOF (fewer than `n` bytes remain)
/// → `.incomplete`.
///
/// `n` is comptime. Zero allocation; the returned slice's
/// lifetime is the caller's input (strictly more durable than
/// the arena).
///
/// Example:
/// ```zig
/// const four = comptime bytes(4);
/// // four.run(&[_]u8{0x01,0x02,0x03,0x04,0x05}, a)
/// //   → ok = .{ .value = &[_]u8{0x01,0x02,0x03,0x04}, .index = 4 }
/// ```
pub fn bytes(comptime n: usize) core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index + n > state.input.len) {
                return .{ .err = core.parseError("binary.bytes", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const slice = state.input[state.index..][0..n];
            state.advance(n);
            // @as: coerce *const [n]u8 → []const u8 so core.ok infers Parser([]const u8) (not Parser(*const [n]u8)).
            return core.ok(@as([]const u8, slice), state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
