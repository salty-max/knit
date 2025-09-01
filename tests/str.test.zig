const std = @import("std");
const P = @import("parsil");

test "str: matches at beginning of input" {
    const res = P.str("pika").run("pikachu");
    try std.testing.expect(res.isOk());
    const ok = res.ok;
    try std.testing.expectEqualStrings("pika", ok.value);
    try std.testing.expectEqual(4, ok.index);
}

test "str: fails when input starts differently" {
    const res = P.str("pika").run("charmander");
    try std.testing.expect(!res.isOk());
    const err = res.err;
    try std.testing.expectEqual(0, err.index);
    try std.testing.expectEqualStrings("expected literal", err.msg);
    try std.testing.expect(err.tag == .ExpectedLiteral);
}

test "str: fails when input is too short" {
    const res = P.str("pikachu").run("pika");
    try std.testing.expect(!res.isOk());
    const err = res.err;
    try std.testing.expectEqual(4, err.index);
    try std.testing.expectEqualStrings("unexpected end of input", err.msg);
    try std.testing.expect(err.tag == .UnexpectedEoF);
}
