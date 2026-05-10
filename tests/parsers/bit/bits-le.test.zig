const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "bitsLe: reads 8 bits LSB-first from a single byte" {
    // Byte 0b10100000 = 0xA0. LSB-first: bits 0,1,2,...,7 = 0,0,0,0,0,1,0,1
    // Result with bit i in position i: 0b00000000 | (1<<5) | (1<<7) = 0b10100000 = 0xA0.
    // (For a single full byte, LSB-first reconstruction yields the same byte value.)
    const buf = [_]u8{0xA0};
    const r = P.bit.bitsLe(8).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0xA0), r.ok.value);
}

test "bitsLe: reads 3 bits LSB-first" {
    // Byte 0b00000101 = 5. LSB-first 3 bits: 1, 0, 1.
    // Result: bit 0 = 1, bit 1 = 0, bit 2 = 1 → 0b101 = 5.
    const buf = [_]u8{0x05};
    const r = P.bit.bitsLe(3).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 5), r.ok.value);
}

test "bitsLe: reads 1 bit (smallest valid n)" {
    const buf = [_]u8{0x01}; // LSB set
    const r = P.bit.bitsLe(1).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 1), r.ok.value);
}

test "bitsLe: short input is incomplete" {
    const buf = [_]u8{0x01};
    const r = P.bit.bitsLe(12).run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bitsLe: empty input is incomplete" {
    const r = P.bit.bitsLe(8).run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
