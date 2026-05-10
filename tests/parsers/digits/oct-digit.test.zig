const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "octDigit: matches 0" {
    const r = P.octDigit().run("0", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '0'), r.ok.value);
}

test "octDigit: matches 7" {
    const r = P.octDigit().run("7", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '7'), r.ok.value);
}

test "octDigit: rejects 8" {
    var owned = try P.octDigit().runArena("8", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "octDigit: rejects letter" {
    var owned = try P.octDigit().runArena("a", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "octDigit: empty input is incomplete" {
    const r = P.octDigit().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
