const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "sepBy: empty input — empty slice, cursor 0" {
    const p = comptime P.sepBy(P.char(','), P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "sepBy: zero matches at cursor — empty slice, cursor unchanged" {
    const p = comptime P.sepBy(P.char(','), P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}

test "sepBy: single match" {
    const p = comptime P.sepBy(P.char(','), P.digit());
    var owned = try p.runArena("3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, '3'), owned.result.ok.value[0]);
}

test "sepBy: multiple matches" {
    const p = comptime P.sepBy(P.char(','), P.digit());
    var owned = try p.runArena("1,2,3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, '1'), owned.result.ok.value[0]);
    try std.testing.expectEqual(@as(u21, '3'), owned.result.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.index);
}

test "sepBy: trailing separator is left in the input (cursor at sep)" {
    const p = comptime P.sepBy(P.char(','), P.digit());
    var owned = try p.runArena("1,2,", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "sepBy: works with multi-byte values" {
    const p = comptime P.sepBy(P.char('-'), P.letters());
    var owned = try p.runArena("foo-bar-baz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("foo", owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("baz", owned.result.ok.value[2]);
}

test "sepBy: composes with .map() to count matches" {
    const Build = struct {
        fn count(s: []u21) usize {
            return s.len;
        }
    };
    const p = comptime P.sepBy(P.char(','), P.digit()).map(usize, Build.count);
    var owned = try p.runArena("1,2,3,4", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.value);
}
