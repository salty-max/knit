const core = @import("core");
const internal = @import("internal.zig");

/// Read `n` bits from the cursor as a `u64`, little-endian bit
/// order (the FIRST bit read becomes the least-significant bit
/// of the result; bytes are consumed in input order, but bits
/// within each byte are taken LSB-first). `n` is comptime and
/// must be in `1..=64`.
///
/// Cursor advances by exactly `n` bits, crossing byte boundaries
/// as needed.
///
/// EOF (fewer than `n` bits remaining) → `.incomplete`.
///
/// **Note on bit order semantics.** "Little-endian" for bits is
/// less standardised than for bytes — this implementation reads
/// bytes in input order and packs LSB-first within each byte. If
/// you need a different bit-packing convention, build it via
/// `bit.any()` plus a `.map`.
///
/// Example:
/// ```zig
/// // Byte 0xA0 = 0b10100000.
/// // bitsLe(3) reads "000" (LSB-first) → 0.
/// // bitsLe(8) reads "00000101" (the byte LSB-first) → 5.
/// ```
pub fn bitsLe(comptime n: u8) core.Parser(u64) {
    if (n == 0 or n > 64) @compileError("bitsLe: n must be in 1..=64");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u64) {
            if (internal.bitsRemaining(state) < n) {
                return .{ .err = core.parseError("bitsLe", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            var result: u64 = 0;
            var i: u8 = 0;
            while (i < n) : (i += 1) {
                const b: u1 = internal.readBitLe(state);
                state.advanceBits(1);
                // @as: widen u1 → u64 so the shift expression has the right result type for the OR.
                result |= @as(u64, b) << @intCast(i);
            }
            return core.ok(result, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
