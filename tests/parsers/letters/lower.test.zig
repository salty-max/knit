const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "lower: matches a" {
    const r = P.lower().run("a", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "lower: matches z" {
    const r = P.lower().run("z", a);
    try std.testing.expect(r == .ok);
}

test "lower: rejects uppercase" {
    var owned = try P.lower().runArena("A", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "lower: rejects digit" {
    var owned = try P.lower().runArena("3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "lower: empty input is incomplete" {
    const r = P.lower().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
