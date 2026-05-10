const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "index: returns 0 at start of input" {
    const r = P.index().run("anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "index: returns current cursor inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.str("hello"), P.index() });
    const r = p.run("hello world", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value[0]);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "index: works at end of input" {
    const p = comptime P.sequenceOf(.{ P.str("hello"), P.index() });
    const r = p.run("hello", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value[1]);
}

test "index: never consumes" {
    // Two consecutive index() calls should return the same value.
    const p = comptime P.sequenceOf(.{ P.str("hi"), P.index(), P.index() });
    const r = p.run("hi!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 2), r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 2), r.ok.value[2]);
}
