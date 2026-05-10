const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "binary.f32le: reads 1.0" {
    // f32 1.0 = 0x3F800000 (big-endian bits) → little-endian bytes 00 00 80 3F
    const buf = [_]u8{ 0x00, 0x00, 0x80, 0x3F };
    const r = P.binary.f32le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f32, 1.0), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "binary.f32be: reads 1.0" {
    const buf = [_]u8{ 0x3F, 0x80, 0x00, 0x00 };
    const r = P.binary.f32be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f32, 1.0), r.ok.value);
}

test "binary.f32le: reads -1.0" {
    // f32 -1.0 = 0xBF800000 (big-endian bits) → little-endian bytes 00 00 80 BF
    const buf = [_]u8{ 0x00, 0x00, 0x80, 0xBF };
    const r = P.binary.f32le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f32, -1.0), r.ok.value);
}

test "binary.f64le: reads 3.14 round-trip via std write+read" {
    // Write 3.14 as f64 LE via std.mem.writeInt(@bitCast), then verify
    // we read back the same value. Avoids hand-encoding the bit pattern.
    var buf: [8]u8 = undefined;
    const expected: f64 = 3.14;
    std.mem.writeInt(u64, &buf, @bitCast(expected), .little);
    const r = P.binary.f64le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(expected, r.ok.value);
}

test "binary.f64be: reads round-trip via std write+read" {
    var buf: [8]u8 = undefined;
    const expected: f64 = -2.718281828;
    std.mem.writeInt(u64, &buf, @bitCast(expected), .big);
    const r = P.binary.f64be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(expected, r.ok.value);
}

test "binary.f32le: short input (3 bytes) is incomplete" {
    const buf = [_]u8{ 0x00, 0x00, 0x80 };
    const r = P.binary.f32le().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.f64be: empty input is incomplete" {
    const r = P.binary.f64be().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
