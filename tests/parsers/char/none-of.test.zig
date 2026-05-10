const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "noneOf: matches a non-member" {
    const p = comptime P.noneOf(&.{ '"', '\'', '\\' });
    const r = p.run("abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "noneOf: rejects a member" {
    const p = comptime P.noneOf(&.{ '"', '\'' });
    var owned = try p.runArena("\"hi", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("noneOf", owned.result.err.parser);
}

test "noneOf: works with multi-byte codepoints" {
    const p = comptime P.noneOf(&.{'🎉'});
    var owned = try p.runArena("🎉", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("noneOf", owned.result.err.parser);
}

test "noneOf: rejection carries actual + comptime-formatted expected" {
    const p = comptime P.noneOf(&.{ '"', '\'' });
    var owned = try p.runArena("\"hi", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("\"", owned.result.err.actual.?);
    try std.testing.expectEqualStrings("none of: '\"', '''", owned.result.err.expected.?);
}
