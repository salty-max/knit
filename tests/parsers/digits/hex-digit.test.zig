const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "hexDigit: matches 0-9" {
    const r = P.hexDigit().run("7", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '7'), r.ok.value);
}

test "hexDigit: matches a-f" {
    const r = P.hexDigit().run("c", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'c'), r.ok.value);
}

test "hexDigit: matches A-F" {
    const r = P.hexDigit().run("F", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'F'), r.ok.value);
}

test "hexDigit: rejects g" {
    var owned = try P.hexDigit().runArena("g", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("hexDigit", owned.result.err.parser);
}

test "hexDigit: empty input is incomplete" {
    const r = P.hexDigit().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
