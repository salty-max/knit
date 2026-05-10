const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "alphaNum: matches lowercase letter" {
    const r = P.alphaNum().run("a", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "alphaNum: matches uppercase letter" {
    const r = P.alphaNum().run("Z", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'Z'), r.ok.value);
}

test "alphaNum: matches digit" {
    const r = P.alphaNum().run("5", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '5'), r.ok.value);
}

test "alphaNum: rejects punctuation" {
    var owned = try P.alphaNum().runArena("!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "alphaNum: empty input is incomplete" {
    const r = P.alphaNum().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
