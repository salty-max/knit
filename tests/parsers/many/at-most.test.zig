const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "atMost: caps at n even if more would match" {
    const p = comptime P.atMost(2, P.digit());
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.index);
}

test "atMost: ok with fewer than n matches" {
    const p = comptime P.atMost(5, P.digit());
    var owned = try p.runArena("12x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
}

test "atMost: empty input — ok empty" {
    const p = comptime P.atMost(3, P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}

test "atMost: zero matches at cursor — ok empty" {
    const p = comptime P.atMost(3, P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}
