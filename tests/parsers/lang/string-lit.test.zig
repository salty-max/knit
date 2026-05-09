const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "stringLit: empty string" {
    var owned = try P.stringLit().runArena("\"\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("", owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.index);
}

test "stringLit: simple ASCII" {
    var owned = try P.stringLit().runArena("\"hello\"rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("hello", owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 7), owned.result.ok.index);
}

test "stringLit: \\n escape decodes to LF" {
    var owned = try P.stringLit().runArena("\"a\\nb\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("a\nb", owned.result.ok.value);
}

test "stringLit: \\t \\r escapes" {
    var owned = try P.stringLit().runArena("\"\\t\\r\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("\t\r", owned.result.ok.value);
}

test "stringLit: \\\\ and \\\" escapes" {
    var owned = try P.stringLit().runArena("\"\\\\and\\\"\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("\\and\"", owned.result.ok.value);
}

test "stringLit: \\xHH hex escape" {
    var owned = try P.stringLit().runArena("\"\\x41\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("A", owned.result.ok.value);
}

test "stringLit: \\xFF hex escape (high byte)" {
    var owned = try P.stringLit().runArena("\"\\xFF\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u8, 0xFF), owned.result.ok.value[0]);
}

test "stringLit: missing opening quote" {
    var owned = try P.stringLit().runArena("hello", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "stringLit: unterminated string — incomplete" {
    var owned = try P.stringLit().runArena("\"unterminated", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "stringLit: bad escape character" {
    var owned = try P.stringLit().runArena("\"\\z\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "stringLit: bad hex digit in \\xHH escape" {
    var owned = try P.stringLit().runArena("\"\\xZZ\"", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.lexical, owned.result.err.kind);
}

test "stringLit: incomplete \\xH (only one hex digit before close quote)" {
    var owned = try P.stringLit().runArena("\"\\x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "stringLit: result is allocated (not borrowed from input)" {
    // For strings WITH escape processing, the decoded slice is freshly
    // allocated. Confirm a different pointer than the input window.
    const input = "\"a\\nb\"";
    var owned = try P.stringLit().runArena(input, a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    // The decoded "a\nb" cannot share storage with "a\nb" inside "a\\nb"
    // (different byte sequences — one has 4 bytes \\n, the other 1 byte \n).
    try std.testing.expect(@intFromPtr(input.ptr) != @intFromPtr(owned.result.ok.value.ptr));
}
