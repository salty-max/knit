const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "endBy: empty input — ok empty" {
    const p = comptime P.endBy(P.char(';'), P.digits());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}

test "endBy: every item terminated — ok with values" {
    const p = comptime P.endBy(P.char(';'), P.digits());
    var owned = try p.runArena("1;2;3;", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("1", owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("3", owned.result.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 6), owned.result.ok.index);
}

test "endBy: last item missing terminator — err" {
    const p = comptime P.endBy(P.char(';'), P.digits());
    var owned = try p.runArena("1;2;3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // Err is from char(';') failing after digits "3" succeeded.
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
}

test "endBy: leading non-match — ok empty (cursor unchanged)" {
    const p = comptime P.endBy(P.char(';'), P.digits());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "endBy: stops at first non-p, leaves cursor there" {
    // After parsing "1;2;", p tries "x" → fails. Cursor at 4.
    const p = comptime P.endBy(P.char(';'), P.digits());
    var owned = try p.runArena("1;2;xrest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.index);
}
