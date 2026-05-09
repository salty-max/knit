const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "letters: matches a run, stops at first non-letter" {
    const p = comptime P.letters();
    const r = p.run("hello123", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "letters: matches mixed-case run" {
    const p = comptime P.letters();
    const r = p.run("HelloWorld!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("HelloWorld", r.ok.value);
    try std.testing.expectEqual(@as(usize, 10), r.ok.index);
}

test "letters: matches a single letter" {
    const p = comptime P.letters();
    const r = p.run("a", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("a", r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "letters: matches all when input is entirely letters" {
    const p = comptime P.letters();
    const r = p.run("AbCdEfG", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("AbCdEfG", r.ok.value);
    try std.testing.expectEqual(@as(usize, 7), r.ok.index);
}

test "letters: zero matches at cursor is syntactic, cursor unchanged" {
    const p = comptime P.letters();
    const r = p.run("123", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("letters", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "letters: empty input is incomplete (EOF)" {
    const p = comptime P.letters();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("letters", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "letters: stops at the leading byte of a multi-byte codepoint" {
    const p = comptime P.letters();
    // "café" = 'c' 'a' 'f' 0xC3 0xA9. Scanner should stop at 0xC3.
    const r = p.run("café", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("caf", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "letters: stops at an invalid UTF-8 byte without inspecting it" {
    const p = comptime P.letters();
    const buf = [_]u8{ 'h', 'i', 0xFF };
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hi", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "letters: stops at digits (boundary between letter and digit runs)" {
    const p = comptime P.letters();
    const r = p.run("abc42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("abc", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}
