const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "binary.u64le: reads little-endian" {
    const buf = [_]u8{ 0xEF, 0xCD, 0xAB, 0x90, 0x78, 0x56, 0x34, 0x12 };
    const r = P.binary.u64le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0x1234567890ABCDEF), r.ok.value);
    try std.testing.expectEqual(@as(usize, 8), r.ok.index);
}

test "binary.u64be: reads big-endian" {
    const buf = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x90, 0xAB, 0xCD, 0xEF };
    const r = P.binary.u64be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u64, 0x1234567890ABCDEF), r.ok.value);
}

test "binary.i64le: reads negative" {
    const buf = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
    const r = P.binary.i64le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -1), r.ok.value);
}

test "binary.i64be: reads min i64" {
    const buf = [_]u8{ 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const r = P.binary.i64be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, std.math.minInt(i64)), r.ok.value);
}

test "binary.u64le: short input (7 bytes) is incomplete" {
    const buf = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 };
    const r = P.binary.u64le().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.u64be: empty input is incomplete" {
    const r = P.binary.u64be().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
