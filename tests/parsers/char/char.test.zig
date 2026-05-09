const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "char: matches ASCII codepoint, advances by 1 byte" {
    const p = comptime P.char('a');
    const r = p.run("apple", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "char: matches 2-byte codepoint, advances by 2 bytes" {
    const p = comptime P.char('é');
    const r = p.run("été", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'é'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "char: matches 3-byte codepoint" {
    const p = comptime P.char('日');
    const r = p.run("日本", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '日'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "char: matches 4-byte codepoint" {
    const p = comptime P.char('🎉');
    const r = p.run("🎉 party", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '🎉'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "char: mismatch is syntactic" {
    const p = comptime P.char('a');
    const r = p.run("xyz", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("char", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "char: empty input is incomplete" {
    const p = comptime P.char('a');
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
