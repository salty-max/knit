const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "anyCharExcept: returns a byte that doesn't start the forbidden parse" {
    const p = comptime P.anyCharExcept(P.char(';'));
    const r = p.run("a;rest", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 'a'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "anyCharExcept: rejects when forbidden parser matches at cursor" {
    const p = comptime P.anyCharExcept(P.char(';'));
    var owned = try p.runArena(";rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("anyCharExcept", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "anyCharExcept: empty input is incomplete" {
    const p = comptime P.anyCharExcept(P.char(';'));
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "anyCharExcept: with multi-char forbidden parser (str)" {
    const p = comptime P.anyCharExcept(P.str("END"));
    const r1 = p.run("aEND", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expectEqual(@as(u8, 'a'), r1.ok.value);
    var owned = try p.runArena("END", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "anyCharExcept: composes with many to consume until sentinel" {
    // Read bytes until we'd see ';' — like a simpler everythingUntil.
    const p = comptime P.many(P.anyCharExcept(P.char(';')));
    var owned = try p.runArena("hello;rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.value.len);
}
