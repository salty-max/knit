const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "bitsBe: reads 8 bits from a single byte" {
    const buf = [_]u8{0xAB};
    const r = P.bit.bitsBe(8).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0xAB), r.ok.value);
}

test "bitsBe: reads 12 bits across two bytes (issue acceptance)" {
    // Bytes 0xAB 0xCD = 0b10101011 0b11001101.
    // First 12 bits MSB-first: 101010111100 = 0xABC.
    const buf = [_]u8{ 0xAB, 0xCD };
    const r = P.bit.bitsBe(12).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0xABC), r.ok.value);
}

test "bitsBe: reads 1 bit (smallest valid n)" {
    const buf = [_]u8{0x80}; // MSB set
    const r = P.bit.bitsBe(1).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 1), r.ok.value);
}

test "bitsBe: reads 64 bits (largest valid n)" {
    const buf = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0 };
    const r = P.bit.bitsBe(64).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0x123456789ABCDEF0), r.ok.value);
}

test "bitsBe: short input is incomplete" {
    const buf = [_]u8{0xAB};
    const r = P.bit.bitsBe(12).run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bitsBe: empty input is incomplete" {
    const r = P.bit.bitsBe(8).run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bitsBe: 12 + 4 + binary.u8 — issue acceptance scenario" {
    // 12 bits + 4 bits = 16 bits = 2 bytes. After these the cursor
    // is at byte 2, byte-aligned. The byte parser then reads byte 2.
    const buf = [_]u8{ 0xAB, 0xCD, 0x42 };
    const p = comptime P.sequenceOf(.{ P.bit.bitsBe(12), P.bit.bitsBe(4), P.binary.u8() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0xABC), r.ok.value[0]);
    try std.testing.expectEqual(@as(u64, 0xD), r.ok.value[1]);
    try std.testing.expectEqual(@as(u8, 0x42), r.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}
