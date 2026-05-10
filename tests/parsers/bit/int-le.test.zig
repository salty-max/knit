const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "bit.intLe: 4-bit positive — 0b0001 LSB-first reads 1,0,0,0 → value 0b0001 = 1" {
    // Wait — for LE bit order, first bit read becomes LSB. From byte
    // 0b00000001, LSB-first bits: 1,0,0,0,0,0,0,0. Take first 4 → 1,0,0,0.
    // Result with bit i in position i: bit 0=1, bit 1=0, bit 2=0, bit 3=0
    // → value 0b0001 = 1.
    const buf = [_]u8{0x01};
    const r = P.bit.intLe(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 1), r.ok.value);
}

test "bit.intLe: 4-bit negative — sign bit (high bit of 4-bit value) set" {
    // To get value 0b1000 = -8 in 4-bit two's complement, LSB-first bits are 0,0,0,1.
    // From byte 0b00001000 = 0x08, LSB-first: 0,0,0,1,0,0,0,0. Take 4 → 0,0,0,1.
    // Reconstruct: bit 0=0, bit 1=0, bit 2=0, bit 3=1 → 0b1000 = -8 signed.
    const buf = [_]u8{0x08};
    const r = P.bit.intLe(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -8), r.ok.value);
}

test "bit.intLe: 8-bit -1 (0xFF — all bits set, regardless of order)" {
    const buf = [_]u8{0xFF};
    const r = P.bit.intLe(8).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -1), r.ok.value);
}

test "bit.intLe: 1-bit (smallest n)" {
    const buf0 = [_]u8{0x00};
    const r0 = P.bit.intLe(1).run(&buf0, a);
    try std.testing.expect(r0 == .ok);
    try std.testing.expectEqual(@as(i64, 0), r0.ok.value);

    const buf1 = [_]u8{0x01}; // LSB set
    const r1 = P.bit.intLe(1).run(&buf1, a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expectEqual(@as(i64, -1), r1.ok.value);
}

test "bit.intLe: short input — incomplete" {
    const buf = [_]u8{0x01};
    const r = P.bit.intLe(16).run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
