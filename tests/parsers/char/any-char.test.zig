const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "anyChar: matches first ASCII codepoint" {
    const p = comptime P.anyChar();
    const r = p.run("hello", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'h'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "anyChar: matches multi-byte codepoint and advances by full width" {
    const p = comptime P.anyChar();
    const r = p.run("☃ snowman", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '☃'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "anyChar: empty input is incomplete" {
    const p = comptime P.anyChar();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
