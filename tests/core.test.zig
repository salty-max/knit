const std = @import("std");
const P = @import("parsil");

test "parseError: factory builds the rich shape with defaults" {
    const e = P.core.parseError("char", 5, "expected codepoint", .{});
    try std.testing.expectEqualStrings("char", e.parser);
    try std.testing.expectEqual(@as(usize, 5), e.index);
    try std.testing.expectEqualStrings("expected codepoint", e.message);
    try std.testing.expect(e.expected == null);
    try std.testing.expect(e.actual == null);
    try std.testing.expectEqual(@as(usize, 0), e.context.len);
}

test "parseError: factory carries expected and actual" {
    const e = P.core.parseError("str", 0, "expected literal", .{
        .expected = "hello",
        .actual = "world",
    });
    try std.testing.expectEqualStrings("hello", e.expected.?);
    try std.testing.expectEqualStrings("world", e.actual.?);
}

test "formatParseError: minimal shape" {
    const e = P.core.parseError("str", 5, "expected literal", .{});
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("ParseError @ index 5 -> str: expected literal", s);
}

test "formatParseError: with single-level context" {
    const e: P.core.ParseError = .{
        .parser = "expr",
        .index = 12,
        .message = "expected operand",
        .context = &.{"function call"},
    };
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("ParseError [function call] @ index 12 -> expr: expected operand", s);
}

test "formatParseError: nested context joined outer-first with ' > '" {
    const e: P.core.ParseError = .{
        .parser = "expr",
        .index = 12,
        .message = "expected operand",
        .context = &.{ "function call", "argument list", "expression" },
    };
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings(
        "ParseError [function call > argument list > expression] @ index 12 -> expr: expected operand",
        s,
    );
}
