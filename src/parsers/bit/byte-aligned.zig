const core = @import("core");

/// Assert the cursor is byte-aligned (`bit_offset == 0`).
/// Returns `Parser(void)`. Insert before a byte parser when you
/// want to explicitly reject leftover sub-byte state from a
/// prior bit read — without it, `state.advance(n)` silently
/// resets `bit_offset` to 0 and discards the partial byte.
///
/// Example:
/// ```zig
/// // After exactly two bytes worth of bits (12 + 4), the cursor
/// // is byte-aligned and `byteAligned()` succeeds.
/// const grammar = comptime sequenceOf(.{
///     bitsBe(12),
///     bitsBe(4),
///     byteAligned(),
///     binary.u8(),
/// });
/// ```
pub fn byteAligned() core.Parser(void) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(void) {
            if (state.bit_offset != 0) {
                return .{ .err = core.parseError("byteAligned", state.index, "expected byte-aligned cursor", .{
                    .kind = .syntactic,
                }) };
            }
            return .{ .ok = .{ .value = {}, .index = state.index } };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
