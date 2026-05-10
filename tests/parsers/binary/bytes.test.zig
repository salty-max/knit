const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "binary.bytes: reads exactly n bytes" {
    const buf = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05 };
    const r = P.binary.bytes(4).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 4), r.ok.value.len);
    try std.testing.expectEqual(@as(u8, 0x01), r.ok.value[0]);
    try std.testing.expectEqual(@as(u8, 0x04), r.ok.value[3]);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "binary.bytes: borrows from input (zero copy)" {
    const buf = [_]u8{ 0x01, 0x02, 0x03 };
    const r = P.binary.bytes(3).run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@intFromPtr(&buf), @intFromPtr(r.ok.value.ptr));
}

test "binary.bytes: short input is incomplete" {
    const buf = [_]u8{ 0x01, 0x02 };
    const r = P.binary.bytes(4).run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.bytes: empty input is incomplete" {
    const r = P.binary.bytes(1).run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.bytes: n=0 succeeds with empty slice" {
    const r = P.binary.bytes(0).run("anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "binary.bytes: composes inside sequenceOf" {
    const buf = [_]u8{ 0x01, 0x02, 0x03, 0x04 };
    const p = comptime P.sequenceOf(.{ P.binary.bytes(2), P.binary.bytes(2) });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0x01), r.ok.value[0][0]);
    try std.testing.expectEqual(@as(u8, 0x03), r.ok.value[1][0]);
}
