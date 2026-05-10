const core = @import("core");
const internal = @import("internal.zig");

/// Assert the next bit (MSB-first within each byte) is `1`;
/// consume it. Returns `Parser(void)`. EOF → `.incomplete`;
/// next bit is `0` → `.syntactic`.
///
/// Symmetric counterpart to `bit.zero()`. Same cursor-advance
/// semantics as `any()` — `bit_offset` bumps by 1.
///
/// Example:
/// ```zig
/// // Byte 0x80 = 0b10000000 — MSB is 1.
/// const buf = [_]u8{0x80};
/// const o = comptime one();
/// // o.run(&buf, a) → ok at index 0 (cursor advanced to bit 1)
/// ```
pub fn one() core.Parser(void) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(void) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("bit.one", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const value = internal.readBitBe(state);
            if (value != 1) {
                return .{ .err = core.parseError("bit.one", state.index, "expected 1 bit", .{
                    .kind = .syntactic,
                }) };
            }
            state.advanceBits(1);
            return .{ .ok = .{ .value = {}, .index = state.index } };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
