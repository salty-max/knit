const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "binary.u32le: reads little-endian" {
    const buf = [_]u8{ 0x78, 0x56, 0x34, 0x12 };
    const r = P.binary.u32le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u32, 0x12345678), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "binary.u32be: reads big-endian" {
    const buf = [_]u8{ 0x12, 0x34, 0x56, 0x78 };
    const r = P.binary.u32be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u32, 0x12345678), r.ok.value);
}

test "binary.i32le: reads negative" {
    const buf = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
    const r = P.binary.i32le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i32, -1), r.ok.value);
}

test "binary.i32be: reads min i32" {
    const buf = [_]u8{ 0x80, 0x00, 0x00, 0x00 };
    const r = P.binary.i32be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i32, std.math.minInt(i32)), r.ok.value);
}

test "binary.u32le: short input (3 bytes) is incomplete" {
    const buf = [_]u8{ 0x12, 0x34, 0x56 };
    const r = P.binary.u32le().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.u32be: empty input is incomplete" {
    const r = P.binary.u32be().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
