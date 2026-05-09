const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "label: success path is transparent" {
    const wrapped = comptime P.label([]const u8, "kw", P.str("then"));
    var owned = try wrapped.runArena("then else", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("then", owned.result.ok.value);
}

test "label: replaces parser identity" {
    const wrapped = comptime P.label([]const u8, "kw", P.str("then"));
    var owned = try wrapped.runArena("xxxx", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("kw", owned.result.err.parser);
}

test "label: preserves inner expected and message" {
    const wrapped = comptime P.label([]const u8, "kw", P.str("then"));
    var owned = try wrapped.runArena("xxxx", a);
    defer owned.deinit();
    // Inner str's "expected" survives the wrap.
    try std.testing.expectEqualStrings("then", owned.result.err.expected.?);
    try std.testing.expectEqualStrings("expected literal", owned.result.err.message);
}

test "label + inContext compose: label replaces, inContext adds context" {
    const wrapped = comptime P.inContext([]const u8, "outer", P.label([]const u8, "kw", P.str("then")));
    var owned = try wrapped.runArena("xxxx", a);
    defer owned.deinit();
    try std.testing.expectEqualStrings("kw", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 1), owned.result.err.context.len);
    try std.testing.expectEqualStrings("outer", owned.result.err.context[0]);
}
