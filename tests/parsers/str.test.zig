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
    // EOF mid-literal is conceptually 'incomplete' — useful for LSPs that
    // suppress red squiggles while the user is still typing.
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, err.kind);
}

test "str: mismatch is syntactic-kind, fatal-severity by default" {
    const r = P.str("pika").run("charmander");
    const err = try u.assertErr([]const u8, r);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, err.kind);
    try std.testing.expectEqual(P.core.Severity.fatal, err.severity);
}
