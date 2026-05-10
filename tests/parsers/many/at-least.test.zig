const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "atLeast: matches when n satisfied" {
    const p = comptime P.atLeast(2, P.digit());
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.value.len);
}

test "atLeast: matches more than n (no upper bound)" {
    const p = comptime P.atLeast(2, P.digit());
    var owned = try p.runArena("123abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
}

test "atLeast: fails when fewer than n" {
    const p = comptime P.atLeast(3, P.digit());
    var owned = try p.runArena("12x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "atLeast(1, p) is equivalent to manyOne(p)" {
    const al = comptime P.atLeast(1, P.digit());
    const mo = comptime P.manyOne(P.digit());
    var owned1 = try al.runArena("123", a);
    defer owned1.deinit();
    var owned2 = try mo.runArena("123", a);
    defer owned2.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expectEqual(owned1.result.ok.value.len, owned2.result.ok.value.len);
}
