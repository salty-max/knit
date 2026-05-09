const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "noneOf: matches a non-member" {
    const p = comptime P.noneOf(&.{ '"', '\'', '\\' });
    const r = p.run("abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
}

test "noneOf: rejects a member" {
    const p = comptime P.noneOf(&.{ '"', '\'' });
    const r = p.run("\"hi", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("noneOf", r.err.parser);
}

test "noneOf: works with multi-byte codepoints" {
    const p = comptime P.noneOf(&.{'🎉'});
    const r = p.run("🎉", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("noneOf", r.err.parser);
}
