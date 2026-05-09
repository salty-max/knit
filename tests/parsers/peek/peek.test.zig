const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "peek: returns byte at cursor without advancing" {
    const p = comptime P.peek();
    const r = p.run("abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 'a'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "peek: empty input is incomplete" {
    const p = comptime P.peek();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("peek", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "peek: returns the leading byte of a multi-byte codepoint, not the codepoint" {
    // "é" = 0xC3 0xA9 in UTF-8. peek is byte-level.
    const p = comptime P.peek();
    const r = p.run("é", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0xC3), r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "peek: returns an invalid UTF-8 byte without complaint" {
    // peek doesn't decode — 0xFF is fine to return as a raw byte.
    const p = comptime P.peek();
    const buf = [_]u8{0xFF};
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0xFF), r.ok.value);
}

test "peek: composes with sequenceOf — peek then consume" {
    // peek the first byte (without advancing), then digits() actually
    // consumes the digit run. Confirms peek doesn't advance.
    const p = comptime P.sequenceOf(.{ P.peek(), P.digits() });
    const r = p.run("42!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, '4'), r.ok.value[0]);
    try std.testing.expectEqualStrings("42", r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "peek: composes with .map() to test a predicate on the next byte" {
    const Build = struct {
        fn isAlpha(b: u8) bool {
            return (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z');
        }
    };
    const p = comptime P.peek().map(bool, Build.isAlpha);
    const r1 = p.run("a", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expectEqual(true, r1.ok.value);
    const r2 = p.run("3", a);
    try std.testing.expect(r2 == .ok);
    try std.testing.expectEqual(false, r2.ok.value);
}
