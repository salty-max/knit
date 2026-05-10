const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "byteAligned: succeeds at start of input" {
    const r = P.bit.byteAligned().run("anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "byteAligned: succeeds after a full-byte bit read (8 bits)" {
    const buf = [_]u8{ 0xAB, 0xCD };
    const p = comptime P.sequenceOf(.{ P.bit.bitsBe(8), P.bit.byteAligned() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
}

test "byteAligned: fails after a partial-byte bit read (3 bits)" {
    const buf = [_]u8{ 0xAB, 0xCD };
    const p = comptime P.sequenceOf(.{ P.bit.bitsBe(3), P.bit.byteAligned() });
    var owned = try p.runArena(&buf, a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("byteAligned", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "byteAligned: succeeds after 12 + 4 = 16 bits (back to byte boundary)" {
    const buf = [_]u8{ 0xAB, 0xCD };
    const p = comptime P.sequenceOf(.{ P.bit.bitsBe(12), P.bit.bitsBe(4), P.bit.byteAligned() });
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
}
