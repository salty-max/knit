const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "sepEndBy: empty input — empty slice, cursor 0" {
    const p = comptime P.sepEndBy(P.char(','), P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}

test "sepEndBy: single match without trailing sep" {
    const p = comptime P.sepEndBy(P.char(','), P.digit());
    var owned = try p.runArena("7", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.index);
}

test "sepEndBy: matches with trailing sep — sep IS consumed" {
    const p = comptime P.sepEndBy(P.char(','), P.digit());
    var owned = try p.runArena("1,2,", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.index);
}

test "sepEndBy: matches without trailing sep — cursor at last value" {
    const p = comptime P.sepEndBy(P.char(','), P.digit());
    var owned = try p.runArena("1,2,3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.index);
}

test "sepEndBy: zero matches at cursor — empty slice, cursor unchanged" {
    const p = comptime P.sepEndBy(P.char(','), P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}
