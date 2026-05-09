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
    // runArena because the mismatch path allocates `actual` via state.allocator.
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "char: empty input is incomplete" {
    const p = comptime P.char('a');
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "char: truncated UTF-8 sequence is incomplete (issue #27 EOF mid-codepoint)" {
    // 0xC3 is the leading byte of a 2-byte sequence (e.g. 'é' = 0xC3 0xA9).
    // On its own it's a truncated sequence — decodeNext returns
    // Utf8Truncated which char.zig maps to kind = .incomplete.
    const p = comptime P.char('é');
    const truncated = [_]u8{0xC3};
    const r = p.run(&truncated, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "char: invalid UTF-8 leading byte is lexical" {
    // 0xFF is never a valid UTF-8 leading byte.
    const p = comptime P.char('a');
    const invalid = [_]u8{0xFF};
    const r = p.run(&invalid, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.lexical, r.err.kind);
}
