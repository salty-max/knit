const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "sepByOne: single match" {
    const p = comptime P.sepByOne(P.char(','), P.digit());
    var owned = try p.runArena("5", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, '5'), owned.result.ok.value[0]);
}

test "sepByOne: multiple matches" {
    const p = comptime P.sepByOne(P.char(','), P.digit());
    var owned = try p.runArena("1,2,3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
}

test "sepByOne: empty input — fails with inner's incomplete kind" {
    const p = comptime P.sepByOne(P.char(','), P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "sepByOne: zero matches at cursor — fails with inner's syntactic err" {
    const p = comptime P.sepByOne(P.char(','), P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
}

test "sepByOne: trailing separator is left in the input" {
    const p = comptime P.sepByOne(P.char(','), P.digit());
    var owned = try p.runArena("1,2,", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}
