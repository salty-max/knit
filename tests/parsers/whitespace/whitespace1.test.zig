const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "whitespace1: matches a run of spaces" {
    const p = comptime P.whitespace1();
    const r = p.run("   hi", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("   ", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "whitespace1: matches a single whitespace byte" {
    const p = comptime P.whitespace1();
    const r = p.run("\tx", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("\t", r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "whitespace1: preserves CRLF in the slice" {
    const p = comptime P.whitespace1();
    const r = p.run("\r\nabc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("\r\n", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "whitespace1: empty input is incomplete" {
    const p = comptime P.whitespace1();
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("whitespace1", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "whitespace1: non-whitespace cursor is syntactic, cursor unchanged" {
    const p = comptime P.whitespace1();
    const r = p.run("xy", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("whitespace1", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "whitespace1: vertical tab is NOT recognised, fails as syntactic" {
    const p = comptime P.whitespace1();
    const r = p.run("\x0B", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "whitespace1: composes with .map() — Parser([]const u8) → Parser(usize)" {
    const Build = struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    };
    const p = comptime P.whitespace1().map(usize, Build.len);
    const r = p.run("\t\t\t!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 3), r.ok.value);
}
