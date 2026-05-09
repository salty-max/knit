const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "letter: matches lowercase 'a'" {
    const p = comptime P.letter();
    const r = p.run("apple", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "letter: matches uppercase 'Z'" {
    const p = comptime P.letter();
    const r = p.run("Zebra", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'Z'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "letter: rejects a digit" {
    const p = comptime P.letter();
    var owned = try p.runArena("3abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("letter", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "letter: rejects ASCII punctuation" {
    const p = comptime P.letter();
    var owned = try p.runArena("!hi", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "letter: rejects a multi-byte non-letter codepoint" {
    const p = comptime P.letter();
    var owned = try p.runArena("é", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "letter: empty input is incomplete (EOF)" {
    const p = comptime P.letter();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("letter", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
