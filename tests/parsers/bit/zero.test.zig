const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "bit.zero: matches when MSB is 0" {
    // 0x40 = 0b01000000 — MSB is 0.
    const buf = [_]u8{0x40};
    const r = P.bit.zero().run(&buf, a);
    try std.testing.expect(r == .ok);
}

test "bit.zero: rejects when MSB is 1" {
    // 0x80 = 0b10000000 — MSB is 1.
    const buf = [_]u8{0x80};
    const r = P.bit.zero().run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "bit.zero: empty input is incomplete" {
    const r = P.bit.zero().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "bit.zero: advances bit_offset by 1 (composes inside sequenceOf)" {
    // 0x40 = 01000000 — 0 then 1, then 6 zeros.
    const buf = [_]u8{0x40};
    const p = comptime P.sequenceOf(.{ P.bit.zero(), P.bit.one() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
}
