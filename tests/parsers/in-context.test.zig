const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "inContext: success path is transparent" {
    const wrapped = comptime P.inContext([]const u8, "outer", P.str("hi"));
    var owned = try wrapped.runArena("hi there", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("hi", owned.result.ok.value);
}

test "inContext: single label lands at context[0]" {
    const wrapped = comptime P.inContext([]const u8, "outer", P.str("hi"));
    var owned = try wrapped.runArena("nope", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(@as(usize, 1), owned.result.err.context.len);
    try std.testing.expectEqualStrings("outer", owned.result.err.context[0]);
}

test "inContext: three-level nest is outer-first" {
    const wrapped = comptime P.inContext([]const u8, "outer", P.inContext([]const u8, "middle", P.inContext([]const u8, "inner", P.str("hi"))));
    var owned = try wrapped.runArena("nope", a);
    defer owned.deinit();
    const ctx = owned.result.err.context;
    try std.testing.expectEqual(@as(usize, 3), ctx.len);
    try std.testing.expectEqualStrings("outer", ctx[0]);
    try std.testing.expectEqualStrings("middle", ctx[1]);
    try std.testing.expectEqualStrings("inner", ctx[2]);
}

test "inContext: preserves inner parser identity and message" {
    const wrapped = comptime P.inContext([]const u8, "outer", P.str("hi"));
    var owned = try wrapped.runArena("nope", a);
    defer owned.deinit();
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
    try std.testing.expectEqualStrings("expected literal", owned.result.err.message);
}
