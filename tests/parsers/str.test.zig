const std = @import("std");
const P = @import("parsil");
const u = @import("util");

test "str: matches at beginning of input" {
    const r = P.str("pika").run("pikachu");
    try u.assertOkStrAt(r, "pika", 4);
}

test "str: fails when input starts differently" {
    const r = P.str("pika").run("charmander");
    try u.assertErrAt([]const u8, r, 0, .ExpectedLiteral);
    try u.expectErrorMessageContains([]const u8, r, "expected literal");
}

test "str: fails when input is too short" {
    const r = P.str("pikachu").run("pika");
    try u.assertErrAt([]const u8, r, 4, .UnexpectedEoF);
    try u.expectErrorMessageContains([]const u8, r, "unexpected end of input");
}
