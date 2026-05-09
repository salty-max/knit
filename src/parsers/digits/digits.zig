const core = @import("core");

/// Match one-or-more contiguous ASCII decimal digits and return the
/// matched byte slice borrowed from the input. The slice's lifetime
/// is the input's — `digits` allocates nothing.
///
/// Implementation note: ASCII digits are always 1-byte (0x30..0x39),
/// so the inner loop scans bytes directly without UTF-8 decoding.
/// A non-digit byte (including the leading byte of any multi-byte
/// codepoint and any invalid byte) ends the match cleanly.
///
/// Failure modes:
/// - Empty input at cursor: `kind = .incomplete`.
/// - First byte is not a digit: `kind = .syntactic`, cursor unchanged.
///
/// Example:
/// ```zig
/// const ds = comptime digits();
/// // ds.run("12abc", alloc) → ok = .{ .value = "12", .index = 2 }
/// // ds.run("abc", alloc)   → err with parser = "digits", cursor 0
/// ```
pub fn digits() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("digits", state.index, "unexpected end of input", .{
                    .expected = "0-9",
                    .kind = .incomplete,
                }) };
            }
            const start = state.index;
            while (state.index < state.input.len) {
                const b = state.input[state.index];
                if (b < '0' or b > '9') break;
                state.advance(1);
            }
            if (state.index == start) {
                return .{ .err = core.parseError("digits", state.index, "expected one or more decimal digits", .{
                    .expected = "0-9",
                    .kind = .syntactic,
                }) };
            }
            return core.ok(state.input[start..state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
