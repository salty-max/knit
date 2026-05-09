const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "sepEndByOne: single match without trailing sep" {
    const p = comptime P.sepEndByOne(P.char(','), P.digit());
    var owned = try p.runArena("9", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
}

test "sepEndByOne: matches with trailing sep — sep IS consumed" {
    const p = comptime P.sepEndByOne(P.char(','), P.digit());
    var owned = try p.runArena("1,2,3,", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 6), owned.result.ok.index);
}

test "sepEndByOne: empty input — fails with inner's incomplete kind" {
    const p = comptime P.sepEndByOne(P.char(','), P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "sepEndByOne: zero matches at cursor — fails with inner's err" {
    const p = comptime P.sepEndByOne(P.char(','), P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
}

test "sepEndByOne: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.sepEndByOne(P.char(','), P.digit()), P.letters() });
    var owned = try p.runArena("1,2,3,abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value[0].len);
    try std.testing.expectEqualStrings("abc", owned.result.ok.value[1]);
}
