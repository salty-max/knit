const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "upper: matches A" {
    const r = P.upper().run("A", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'A'), r.ok.value);
}

test "upper: matches Z" {
    const r = P.upper().run("Z", a);
    try std.testing.expect(r == .ok);
}

test "upper: rejects lowercase" {
    var owned = try P.upper().runArena("a", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "upper: rejects digit" {
    var owned = try P.upper().runArena("3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "upper: empty input is incomplete" {
    const r = P.upper().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
