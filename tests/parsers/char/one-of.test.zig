const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "oneOf: matches a member of the set" {
    const p = comptime P.oneOf(&.{ 'a', 'e', 'i', 'o', 'u' });
    const r = p.run("apple", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "oneOf: rejects a non-member" {
    const p = comptime P.oneOf(&.{ 'a', 'b', 'c' });
    const r = p.run("xyz", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("oneOf", r.err.parser);
}

test "oneOf: works with multi-byte codepoints" {
    const p = comptime P.oneOf(&.{ '日', '本' });
    const r = p.run("日本", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '日'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}
