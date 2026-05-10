const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "bit.one: matches when MSB is 1" {
    const buf = [_]u8{0x80};
    const r = P.bit.one().run(&buf, a);
    try std.testing.expect(r == .ok);
}

test "bit.one: rejects when MSB is 0" {
    const buf = [_]u8{0x40};
    const r = P.bit.one().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "bit.one: empty input is incomplete" {
    const r = P.bit.one().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bit.one: 8 successive ones consume an entire 0xFF byte" {
    const buf = [_]u8{0xFF};
    const p = comptime P.sequenceOf(.{
        P.bit.one(), P.bit.one(), P.bit.one(), P.bit.one(),
        P.bit.one(), P.bit.one(), P.bit.one(), P.bit.one(),
    });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
}
