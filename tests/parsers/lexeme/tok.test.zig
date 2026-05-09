const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "tok: runs p then consumes trailing whitespace" {
    const p = comptime P.tok(P.digits());
    const r = p.run("42  next", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "tok: no trailing whitespace — cursor right after p" {
    const p = comptime P.tok(P.digits());
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "tok: trailing whitespace at EOF is fully consumed" {
    const p = comptime P.tok(P.digits());
    const r = p.run("42   ", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "tok: tab + newline + CR all count as whitespace" {
    const p = comptime P.tok(P.digits());
    const r = p.run("42\t\n\rx", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "tok: failure of inner propagates with cursor at the failing position" {
    const p = comptime P.tok(P.digits());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digits", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "tok: composes inside sequenceOf — token-aware grammar" {
    // Two consecutive tokenised items: digits then letters, both with
    // optional whitespace between/after.
    const p = comptime P.sequenceOf(.{ P.tok(P.digits()), P.tok(P.letters()) });
    const r = p.run("42  hello", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value[0]);
    try std.testing.expectEqualStrings("hello", r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 9), r.ok.index);
}

test "tok: preserves the inner parser's output type" {
    // tok(char(...)) → Parser(u21), not Parser([]const u8).
    const p = comptime P.tok(P.char('A'));
    const r = p.run("A   rest", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'A'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "tok: with non-consuming inner — just skips whitespace" {
    // succeed always succeeds with zero consumption. tok then
    // skips whitespace from the cursor. Pure whitespace eater,
    // semantically.
    const p = comptime P.tok(P.succeed(u8, 0));
    const r = p.run("   xyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u8, 0), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "tok: composes inside many — tokenised list" {
    // The canonical "lex a list of digit tokens" pattern.
    const p = comptime P.many(P.tok(P.digits()));
    var owned = try p.runArena("12 34 56", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("12", owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("56", owned.result.ok.value[2]);
}

test "tok: composes with .map() on the underlying value" {
    const Build = struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    };
    const p = comptime P.tok(P.digits()).map(usize, Build.len);
    const r = p.run("12345  ", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value);
    try std.testing.expectEqual(@as(usize, 7), r.ok.index);
}
