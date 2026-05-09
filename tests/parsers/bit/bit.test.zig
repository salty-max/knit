const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "bit: reads MSB first" {
    // Byte 0xA0 = 0b10100000.
    const buf = [_]u8{0xA0};
    const p = comptime P.sequenceOf(.{ P.bit.bit(), P.bit.bit(), P.bit.bit() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u1, 1), r.ok.value[0]);
    try std.testing.expectEqual(@as(u1, 0), r.ok.value[1]);
    try std.testing.expectEqual(@as(u1, 1), r.ok.value[2]);
}

test "bit: empty input is incomplete" {
    const r = P.bit.bit().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bit: 8 successive reads consume the whole byte" {
    // Byte 0xAA = 0b10101010 — alternating, MSB first → 1,0,1,0,1,0,1,0.
    const buf = [_]u8{0xAA};
    const p = comptime P.sequenceOf(.{
        P.bit.bit(), P.bit.bit(), P.bit.bit(), P.bit.bit(),
        P.bit.bit(), P.bit.bit(), P.bit.bit(), P.bit.bit(),
    });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    inline for (0..8) |i| {
        const expected: u1 = if (i % 2 == 0) 1 else 0;
        try std.testing.expectEqual(expected, r.ok.value[i]);
    }
}
