const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "any: reads MSB first" {
    // Byte 0xA0 = 0b10100000.
    const buf = [_]u8{0xA0};
    const p = comptime P.sequenceOf(.{ P.bit.any(), P.bit.any(), P.bit.any() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u1, 1), r.ok.value[0]);
    try std.testing.expectEqual(@as(u1, 0), r.ok.value[1]);
    try std.testing.expectEqual(@as(u1, 1), r.ok.value[2]);
}

test "any: empty input is incomplete" {
    const r = P.bit.any().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
    try std.testing.expectEqualStrings("bit.any", r.err.parser);
}

test "any: 8 successive reads consume the whole byte" {
    // Byte 0xAA = 0b10101010 — alternating, MSB first → 1,0,1,0,1,0,1,0.
    const buf = [_]u8{0xAA};
    const p = comptime P.sequenceOf(.{
        P.bit.any(), P.bit.any(), P.bit.any(), P.bit.any(),
        P.bit.any(), P.bit.any(), P.bit.any(), P.bit.any(),
    });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    inline for (0..8) |i| {
        const expected: u1 = if (i % 2 == 0) 1 else 0;
        try std.testing.expectEqual(expected, r.ok.value[i]);
    }
}
