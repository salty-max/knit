const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "binary.u8: reads one byte" {
    const buf = [_]u8{ 0x42, 0x99 };
    const r = P.binary.u8().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0x42), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "binary.u8: reads max byte (0xFF)" {
    const buf = [_]u8{0xFF};
    const r = P.binary.u8().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0xFF), r.ok.value);
}

test "binary.u8: empty input is incomplete" {
    const r = P.binary.u8().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary.i8: reads positive byte" {
    const buf = [_]u8{0x42};
    const r = P.binary.i8().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i8, 66), r.ok.value);
}

test "binary.i8: reads negative byte (two's complement)" {
    const buf = [_]u8{0xFF};
    const r = P.binary.i8().run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i8, -1), r.ok.value);
}

test "binary.i8: empty input is incomplete" {
    const r = P.binary.i8().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "binary: chained reads via sequenceOf — cursor advances correctly between reads" {
    // Verifies that cursor advancement after one binary parser leaves
    // the cursor in the right place for the next. Two u8 reads from a
    // 3-byte buffer; the third byte is left for the next caller.
    const buf = [_]u8{ 0x10, 0x20, 0x30 };
    const p = comptime P.sequenceOf(.{ P.binary.u8(), P.binary.u8() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0x10), r.ok.value[0]);
    try std.testing.expectEqual(@as(u8, 0x20), r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}
