const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "oneOf: matches a member of the set" {
    const p = comptime P.oneOf(&.{ 'a', 'e', 'i', 'o', 'u' });
    const r = p.run("apple", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "oneOf: rejects a non-member" {
    const p = comptime P.oneOf(&.{ 'a', 'b', 'c' });
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("oneOf", owned.result.err.parser);
}

test "oneOf: works with multi-byte codepoints" {
    const p = comptime P.oneOf(&.{ '日', '本' });
    const r = p.run("日本", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '日'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "oneOf: mismatch carries actual + comptime-formatted expected" {
    const p = comptime P.oneOf(&.{ 'a', 'e', 'i' });
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("x", owned.result.err.actual.?);
    try std.testing.expectEqualStrings("one of: 'a', 'e', 'i'", owned.result.err.expected.?);
}
