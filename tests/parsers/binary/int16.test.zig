const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "binary.u16le: reads little-endian (low byte first)" {
    const buf = [_]u8{ 0x34, 0x12 };
    const r = P.binary.u16le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u16, 0x1234), r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "binary.u16be: reads big-endian (high byte first)" {
    const buf = [_]u8{ 0x12, 0x34 };
    const r = P.binary.u16be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u16, 0x1234), r.ok.value);
}

test "binary.u16le vs u16be: same bytes, different values" {
    const buf = [_]u8{ 0xAB, 0xCD };
    const le = P.binary.u16le().run(&buf, a);
    const be = P.binary.u16be().run(&buf, a);
    try std.testing.expectEqual(@as(u16, 0xCDAB), le.ok.value);
    try std.testing.expectEqual(@as(u16, 0xABCD), be.ok.value);
}

test "binary.i16le: reads negative (two's complement)" {
    const buf = [_]u8{ 0xFF, 0xFF };
    const r = P.binary.i16le().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i16, -1), r.ok.value);
}

test "binary.i16be: reads min i16" {
    const buf = [_]u8{ 0x80, 0x00 };
    const r = P.binary.i16be().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i16, -32768), r.ok.value);
}

test "binary.u16le: short input (1 byte) is incomplete" {
    const buf = [_]u8{0x42};
    const r = P.binary.u16le().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.i16be: empty input is incomplete" {
    const r = P.binary.i16be().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
