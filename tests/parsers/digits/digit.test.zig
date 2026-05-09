const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "digit: matches '0'" {
    const p = comptime P.digit();
    const r = p.run("0xyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '0'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "digit: matches '9'" {
    const p = comptime P.digit();
    const r = p.run("9", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '9'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "digit: rejects a non-digit ASCII char" {
    const p = comptime P.digit();
    var owned = try p.runArena("x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "digit: rejects a multi-byte non-digit codepoint" {
    const p = comptime P.digit();
    var owned = try p.runArena("é", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "digit: empty input is incomplete (EOF)" {
    const p = comptime P.digit();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("digit", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "digit: composes with .map() — Parser(u21) → Parser(u8)" {
    const Build = struct {
        fn toValue(cp: u21) u8 {
            return @intCast(cp - '0');
        }
    };
    const p = comptime P.digit().map(u8, Build.toValue);
    const r = p.run("7x", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 7), r.ok.value);
}
