const core = @import("core");
const internal = @import("internal.zig");

/// Read `n` bits from the cursor as a two's-complement signed
/// `i64`, big-endian bit order (the FIRST bit read is the sign
/// bit, becoming the MSB of the value). `n` is comptime and
/// must be in `1..=64`.
///
/// Sign-extension: if the high bit of the read value is `1`, the
/// upper `64 - n` bits of the result are filled with `1`s so the
/// returned `i64` correctly represents the two's-complement value.
///
/// Cursor advances by exactly `n` bits, crossing byte boundaries
/// as needed. EOF (fewer than `n` bits remaining) → `.incomplete`.
///
/// Example:
/// ```zig
/// // 4-bit signed values from a single byte 0x80 = 0b10000000
/// const buf = [_]u8{0x80};
/// const p = comptime intBe(4);
/// // p.run(&buf, a) → ok = .{ .value = -8, ... }  (0b1000 = -8 in 4-bit two's complement)
/// ```
pub fn intBe(comptime n: u8) core.Parser(i64) {
    if (n == 0 or n > 64) @compileError("bit.intBe: n must be in 1..=64");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(i64) {
            if (internal.bitsRemaining(state) < n) {
                return .{ .err = core.parseError("bit.intBe", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            var unsigned: u64 = 0;
            var bits_left: u8 = n;
            while (bits_left > 0) : (bits_left -= 1) {
                const b: u1 = internal.readBitBe(state);
                state.advanceBits(1);
                // @as: widen u1 → u64 so the OR's right operand matches `unsigned`'s type.
                unsigned = (unsigned << 1) | @as(u64, b);
            }
            // Sign-extend via shift-up-then-arithmetic-shift-down.
            const shift_amt: u6 = @intCast(64 - n);
            const shifted_u: u64 = unsigned << shift_amt;
            // safety: bit-pattern reinterpretation between u64 and i64 — both are 64-bit; @bitCast preserves all bits.
            const shifted_i: i64 = @bitCast(shifted_u);
            const value: i64 = shifted_i >> shift_amt;
            return core.ok(value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
