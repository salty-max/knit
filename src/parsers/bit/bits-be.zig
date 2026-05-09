const core = @import("core");
const internal = @import("internal.zig");

/// Read `n` bits from the cursor as a `u64`, big-endian bit
/// order (the FIRST bit read becomes the most-significant bit
/// of the result). `n` is comptime and must be in `1..=64`.
///
/// Cursor advances by exactly `n` bits, crossing byte boundaries
/// as needed (`bit_offset` and `index` both update).
///
/// EOF (fewer than `n` bits remaining) → `.incomplete`.
///
/// Example:
/// ```zig
/// // Bytes 0xAB 0xCD = 0b10101011 0b11001101.
/// // bitsBe(12) reads "101010111100" → 0xABC = 2748.
/// ```
pub fn bitsBe(comptime n: u8) core.Parser(u64) {
    if (n == 0 or n > 64) @compileError("bitsBe: n must be in 1..=64");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u64) {
            if (internal.bitsRemaining(state) < n) {
                return .{ .err = core.parseError("bitsBe", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            var result: u64 = 0;
            var bits_left: u8 = n;
            while (bits_left > 0) {
                const b: u1 = internal.readBitBe(state);
                state.advanceBits(1);
                // @as: widen u1 → u64 so the OR's right operand matches `result`'s type.
                result = (result << 1) | @as(u64, b);
                bits_left -= 1;
            }
            return core.ok(result, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
