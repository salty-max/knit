const std = @import("std");
const P = @import("parsil");
const u = @import("util");

test "str: matches at beginning of input" {
    const r = P.str("pika").run("pikachu");
    try u.assertOkStrAt(r, "pika", 4);
}

test "str: fails when input starts differently" {
    const r = P.str("pika").run("charmander");
    try u.assertErrAt([]const u8, r, 0, "str");
    try u.expectErrorMessageContains([]const u8, r, "expected literal");
    // Rich error: expected/actual carry the contextual slices.
    const err = try u.assertErr([]const u8, r);
    try std.testing.expectEqualStrings("pika", err.expected.?);
    try std.testing.expectEqualStrings("char", err.actual.?);
}

test "str: fails when input is too short" {
    const r = P.str("pikachu").run("pika");
    try u.assertErrAt([]const u8, r, 4, "str");
    try u.expectErrorMessageContains([]const u8, r, "unexpected end of input");
    const err = try u.assertErr([]const u8, r);
    try std.testing.expectEqualStrings("pikachu", err.expected.?);
    try std.testing.expectEqualStrings("pika", err.actual.?);
}
