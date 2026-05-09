const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "identifier: simple lowercase" {
    const r = P.identifier().run("foo", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("foo", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "identifier: leading underscore" {
    const r = P.identifier().run("_priv", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("_priv", r.ok.value);
}

test "identifier: PascalCase + digits" {
    const r = P.identifier().run("Foo_1Bar", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("Foo_1Bar", r.ok.value);
}

test "identifier: stops at non-identifier byte" {
    const r = P.identifier().run("foo bar", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("foo", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "identifier: rejects pure-digit start" {
    var owned = try P.identifier().runArena("9digits", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("identifier", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "identifier: rejects punctuation start" {
    var owned = try P.identifier().runArena("!bang", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "identifier: empty input is incomplete" {
    const r = P.identifier().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "identifier: result borrows from input" {
    const input = "abc xyz";
    const r = P.identifier().run(input, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@intFromPtr(input.ptr), @intFromPtr(r.ok.value.ptr));
}
