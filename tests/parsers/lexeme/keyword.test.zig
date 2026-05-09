const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "keyword: matches literal followed by space + consumes trailing whitespace" {
    const p = comptime P.keyword("if");
    const r = p.run("if foo", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("if", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "keyword: matches at EOF (no trailing byte to check) — ok" {
    const p = comptime P.keyword("if");
    const r = p.run("if", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("if", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "keyword: rejects identifier-continuation byte (letter)" {
    const p = comptime P.keyword("if");
    var owned = try p.runArena("ifx", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("keyword", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "keyword: rejects identifier-continuation byte (digit)" {
    const p = comptime P.keyword("if");
    var owned = try p.runArena("if2", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("keyword", owned.result.err.parser);
}

test "keyword: rejects identifier-continuation byte (underscore)" {
    const p = comptime P.keyword("if");
    var owned = try p.runArena("if_x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("keyword", owned.result.err.parser);
}

test "keyword: accepts non-identifier byte (semicolon)" {
    const p = comptime P.keyword("if");
    const r = p.run("if;rest", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("if", r.ok.value);
    // No whitespace to skip; cursor at ';'.
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "keyword: literal mismatch — err with syntactic kind" {
    const p = comptime P.keyword("if");
    var owned = try p.runArena("else", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("if", owned.result.err.expected.?);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "keyword: not enough input for literal — incomplete kind" {
    const p = comptime P.keyword("return");
    var owned = try p.runArena("ret", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "keyword: empty input — incomplete kind" {
    const p = comptime P.keyword("if");
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "keyword: result borrows from input (zero copy)" {
    const p = comptime P.keyword("if");
    const input = "if foo";
    const r = p.run(input, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@intFromPtr(input.ptr), @intFromPtr(r.ok.value.ptr));
}

test "keyword: identifier-boundary err carries actual = s + offending byte" {
    // The `actual` slice on a boundary-violation err shows what
    // the parser actually saw — the keyword bytes plus the byte
    // that broke the boundary. Useful for diagnostic display.
    const p = comptime P.keyword("if");
    var owned = try p.runArena("ifx", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("ifx", owned.result.err.actual.?);
}

test "keyword: composes inside sequenceOf — keyword + payload" {
    const p = comptime P.sequenceOf(.{ P.keyword("let"), P.letters() });
    const r = p.run("let xyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("let", r.ok.value[0]);
    try std.testing.expectEqualStrings("xyz", r.ok.value[1]);
}
