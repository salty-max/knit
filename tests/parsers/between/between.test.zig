const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "between: matches a parenthesized payload, keeps only inner value" {
    const p = comptime P.between(P.char('('), P.digits(), P.char(')'));
    const r = p.run("(42)abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "between: matches with multi-byte delimiters" {
    const p = comptime P.between(P.str("<<"), P.letters(), P.str(">>"));
    const r = p.run("<<hello>>x", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value);
    try std.testing.expectEqual(@as(usize, 9), r.ok.index);
}

test "between: failure on left propagates with cursor at 0" {
    const p = comptime P.between(P.char('('), P.digits(), P.char(')'));
    var owned = try p.runArena("42)", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "between: failure on inner propagates from p's parser identity" {
    const p = comptime P.between(P.char('('), P.digits(), P.char(')'));
    var owned = try p.runArena("(abc)", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digits", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 1), owned.result.err.index);
}

test "between: failure on right propagates with cursor past inner" {
    const p = comptime P.between(P.char('('), P.digits(), P.char(')'));
    var owned = try p.runArena("(42", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
    try std.testing.expectEqual(@as(usize, 3), owned.result.err.index);
}

test "between: equivalent to .between method form" {
    const free_form = comptime P.between(P.char('['), P.digits(), P.char(']'));
    const method_form = comptime P.digits().between(P.char('['), P.char(']'));
    const r1 = free_form.run("[7]", a);
    const r2 = method_form.run("[7]", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expect(r2 == .ok);
    try std.testing.expectEqualStrings(r1.ok.value, r2.ok.value);
    try std.testing.expectEqual(r1.ok.index, r2.ok.index);
}

test "between: composes inside sequenceOf" {
    const paren = comptime P.between(P.char('('), P.digits(), P.char(')'));
    const p = comptime P.sequenceOf(.{ paren, P.letters() });
    const r = p.run("(42)abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value[0]);
    try std.testing.expectEqualStrings("abc", r.ok.value[1]);
}

test "between: composes with .map() to project the inner value" {
    const Build = struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    };
    const p = comptime P.between(P.char('('), P.digits(), P.char(')')).map(usize, Build.len);
    const r = p.run("(12345)", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value);
}
