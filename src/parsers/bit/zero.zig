const core = @import("core");
const internal = @import("internal.zig");

/// Assert the next bit (MSB-first within each byte) is `0`;
/// consume it. Returns `Parser(void)`. EOF → `.incomplete`;
/// next bit is `1` → `.syntactic`.
///
/// Same cursor-advance semantics as `bit()` — `bit_offset`
/// bumps by 1, crossing byte boundaries via `advanceBits`.
///
/// Example:
/// ```zig
/// // Byte 0x40 = 0b01000000 — MSB is 0.
/// const buf = [_]u8{0x40};
/// const z = comptime zero();
/// // z.run(&buf, a) → ok at index 0 (cursor advanced to bit 1)
/// ```
pub fn zero() core.Parser(void) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(void) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("bit.zero", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const value = internal.readBitBe(state);
            if (value != 0) {
                return .{ .err = core.parseError("bit.zero", state.index, "expected 0 bit", .{
                    .kind = .syntactic,
                }) };
            }
            state.advanceBits(1);
            return .{ .ok = .{ .value = {}, .index = state.index } };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
