const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "endByOne: single terminated item" {
    const p = comptime P.endByOne(P.char(';'), P.digits());
    var owned = try p.runArena("1;", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("1", owned.result.ok.value[0]);
}

test "endByOne: multiple terminated items" {
    const p = comptime P.endByOne(P.char(';'), P.digits());
    var owned = try p.runArena("1;2;3;", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
}

test "endByOne: empty input — fails with inner's incomplete" {
    const p = comptime P.endByOne(P.char(';'), P.digits());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "endByOne: missing terminator after last — err" {
    const p = comptime P.endByOne(P.char(';'), P.digits());
    var owned = try p.runArena("1;2", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
}

test "endByOne: leading non-match — err" {
    const p = comptime P.endByOne(P.char(';'), P.digits());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digits", owned.result.err.parser);
}
