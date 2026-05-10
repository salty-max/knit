const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "repeatBetween: matches min..max range" {
    const p = comptime P.repeatBetween(2, 4, P.digit());
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    // Stops at max=4.
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.index);
}

test "repeatBetween: stops cleanly at max even if more would match" {
    const p = comptime P.repeatBetween(0, 2, P.digit());
    var owned = try p.runArena("99999", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.index);
}

test "repeatBetween: fails when fewer than min" {
    const p = comptime P.repeatBetween(3, 5, P.digit());
    var owned = try p.runArena("12x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // Inner err from digit() failing on 'x'.
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
}

test "repeatBetween: min=0, max=N — atMost shape" {
    const p = comptime P.repeatBetween(0, 3, P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "repeatBetween: min=max — exactly N" {
    const p = comptime P.repeatBetween(3, 3, P.digit());
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
}

test "repeatBetween: no-progress break (inner succeeds without advancing)" {
    // `lookAhead(digit)` succeeds without advancing the cursor —
    // repeatBetween must record once and stop, not spin forever.
    const p = comptime P.repeatBetween(0, 100, P.lookAhead(P.digit()));
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}
