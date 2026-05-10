const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "bit.intBe: 4-bit positive (0b0111 = 7)" {
    const buf = [_]u8{0x70}; // 01110000
    const r = P.bit.intBe(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 7), r.ok.value);
}

test "bit.intBe: 4-bit negative (0b1000 = -8)" {
    const buf = [_]u8{0x80}; // 10000000
    const r = P.bit.intBe(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -8), r.ok.value);
}

test "bit.intBe: 4-bit -1 (0b1111)" {
    const buf = [_]u8{0xF0}; // 11110000
    const r = P.bit.intBe(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -1), r.ok.value);
}

test "bit.intBe: 8-bit -1 (0xFF)" {
    const buf = [_]u8{0xFF};
    const r = P.bit.intBe(8).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -1), r.ok.value);
}

test "bit.intBe: 1-bit (smallest n) — 0 vs -1" {
    const buf0 = [_]u8{0x00};
    const r0 = P.bit.intBe(1).run(&buf0, a);
    try std.testing.expect(r0 == .ok);
    try std.testing.expectEqual(@as(i64, 0), r0.ok.value);

    const buf1 = [_]u8{0x80};
    const r1 = P.bit.intBe(1).run(&buf1, a);
    try std.testing.expect(r1 == .ok);
    // Single sign bit set → -1 in 1-bit two's complement
    try std.testing.expectEqual(@as(i64, -1), r1.ok.value);
}

test "bit.intBe: 64-bit (largest n) — min i64" {
    const buf = [_]u8{ 0x80, 0, 0, 0, 0, 0, 0, 0 };
    const r = P.bit.intBe(64).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, std.math.minInt(i64)), r.ok.value);
}

test "bit.intBe: short input — incomplete" {
    const buf = [_]u8{0xF0};
    const r = P.bit.intBe(16).run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
