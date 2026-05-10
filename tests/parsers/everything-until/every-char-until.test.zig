const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "everyCharUntil: stops just before stopP match (ASCII)" {
    const p = comptime P.everyCharUntil(P.char(']'));
    const r = p.run("abc]xyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("abc", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "everyCharUntil: advances by codepoint width through multi-byte input" {
    // "café]rest": 'c'(1) 'a'(1) 'f'(1) 'é'(2) ']'(1) 'r' 'e' 's' 't'
    // Stop is at byte index 5 (after the 'é' encoding 0xC3 0xA9).
    const p = comptime P.everyCharUntil(P.char(']'));
    const r = p.run("café]rest", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("café", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "everyCharUntil: stopP matches at start — empty slice" {
    const p = comptime P.everyCharUntil(P.char('é'));
    const r = p.run("éabc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "everyCharUntil: EOF without stopP — incomplete" {
    const p = comptime P.everyCharUntil(P.char('z'));
    const r = p.run("abc", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("everyCharUntil", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
    try std.testing.expectEqual(@as(usize, 3), r.err.index);
}

test "everyCharUntil: invalid UTF-8 before stopP — lexical" {
    // 0xFF is never a valid UTF-8 leading byte. stopP would never
    // succeed before it, so we hit decodeNext's invalid path.
    const p = comptime P.everyCharUntil(P.char(']'));
    const buf = [_]u8{ 'a', 'b', 0xFF, ']' };
    const r = p.run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.lexical, r.err.kind);
    try std.testing.expectEqual(@as(usize, 2), r.err.index);
}

test "everyCharUntil: truncated UTF-8 before stopP — incomplete" {
    // 0xC3 is a 2-byte leading byte; alone it's truncated.
    const p = comptime P.everyCharUntil(P.char(']'));
    const buf = [_]u8{ 'a', 'b', 0xC3 };
    const r = p.run(&buf, a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "everyCharUntil: result is a borrow into input (zero copy)" {
    const p = comptime P.everyCharUntil(P.char('|'));
    const input = "café|rest";
    const r = p.run(input, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@intFromPtr(input.ptr), @intFromPtr(r.ok.value.ptr));
}

test "everyCharUntil: composes inside sequenceOf with multi-byte content" {
    const p = comptime P.sequenceOf(.{ P.everyCharUntil(P.char('!')), P.char('!') });
    const r = p.run("Bonjour 日本!end", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("Bonjour 日本", r.ok.value[0]);
    try std.testing.expectEqual(@as(u21, '!'), r.ok.value[1]);
}
