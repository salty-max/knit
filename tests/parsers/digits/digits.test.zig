const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "digits: matches a run, stops at first non-digit" {
    const p = comptime P.digits();
    const r = p.run("12abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("12", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "digits: matches a single digit" {
    const p = comptime P.digits();
    const r = p.run("7", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("7", r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "digits: matches all when input is entirely digits" {
    const p = comptime P.digits();
    const r = p.run("4815162342", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("4815162342", r.ok.value);
    try std.testing.expectEqual(@as(usize, 10), r.ok.index);
}

test "digits: zero matches at cursor is syntactic, cursor unchanged" {
    const p = comptime P.digits();
    const r = p.run("abc", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("digits", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "digits: empty input is incomplete (EOF)" {
    const p = comptime P.digits();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("digits", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "digits: stops at the leading byte of a multi-byte codepoint" {
    const p = comptime P.digits();
    // "12é" = 0x31 0x32 0xC3 0xA9. Scanner should stop at 0xC3.
    const r = p.run("12é", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("12", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "digits: stops at an invalid UTF-8 byte without inspecting it" {
    const p = comptime P.digits();
    const buf = [_]u8{ '1', '2', 0xFF };
    const r = p.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("12", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "digits: composes with .map() — Parser([]const u8) → Parser(usize)" {
    const Build = struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    };
    const p = comptime P.digits().map(usize, Build.len);
    const r = p.run("12345abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value);
}
