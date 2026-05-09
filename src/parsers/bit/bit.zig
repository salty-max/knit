const core = @import("core");
const internal = @import("internal.zig");

/// Read the next single bit at the cursor (big-endian bit order
/// within each byte: MSB at `bit_offset = 0`). Returns `u1` (0
/// or 1). EOF (cursor at or past end-of-input) → `.incomplete`.
///
/// The cursor advances by exactly one bit: `bit_offset` bumps,
/// crossing into the next byte if it reaches 8.
///
/// Example:
/// ```zig
/// // Byte 0xA0 = 0b10100000 — read three bits MSB-first → 1, 0, 1.
/// const buf = [_]u8{0xA0};
/// const b = comptime bit();
/// // Run b three times in a sequenceOf, get .{ 1, 0, 1 }.
/// ```
pub fn bit() core.Parser(u1) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u1) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("bit", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const value = internal.readBitBe(state);
            state.advanceBits(1);
            return core.ok(value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
