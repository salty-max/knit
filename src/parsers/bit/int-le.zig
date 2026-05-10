const core = @import("core");
const internal = @import("internal.zig");

/// Read `n` bits from the cursor as a two's-complement signed
/// `i64`, little-endian bit order (matches `bitsLe`'s bit order:
/// first bit becomes the LSB; bytes still consumed in input
/// order). The sign bit is the LAST bit read (the high bit of
/// the n-bit value), which gets sign-extended into the upper
/// `64 - n` bits.
///
/// `n` is comptime and must be in `1..=64`. Cursor advances by
/// exactly `n` bits. EOF → `.incomplete`.
///
/// Example:
/// ```zig
/// // 4-bit signed value from byte 0b00001000 = 0x08
/// // bitsLe(4) reads "0001" (LSB-first) → value 0b1000 = -8 signed
/// const buf = [_]u8{0x08};
/// const p = comptime intLe(4);
/// // p.run(&buf, a) → ok = .{ .value = -8, ... }
/// ```
pub fn intLe(comptime n: u8) core.Parser(i64) {
    if (n == 0 or n > 64) @compileError("bit.intLe: n must be in 1..=64");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(i64) {
            if (internal.bitsRemaining(state) < n) {
                return .{ .err = core.parseError("bit.intLe", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            var unsigned: u64 = 0;
            var i: u8 = 0;
            while (i < n) : (i += 1) {
                const b: u1 = internal.readBitLe(state);
                state.advanceBits(1);
                // @as: widen u1 → u64 so the shift expression has the right result type for the OR.
                unsigned |= @as(u64, b) << @intCast(i);
            }
            // Sign-extend (same idiom as intBe).
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
