const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

// Sanity-check thunk: a non-recursive parser wrapped in recursive
// should behave identically to the wrapped parser.
fn simpleThunk() P.core.Parser(u21) {
    return P.char('a');
}

test "recursive: wrapping a non-recursive parser is a no-op" {
    const p = comptime P.recursive(u21, simpleThunk);
    const r = p.run("abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "recursive: wrapping a non-recursive parser propagates failures" {
    const p = comptime P.recursive(u21, simpleThunk);
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
}

// Recursive grammar: expr = '(' expr ')' | digit
// The classic test case for self-reference.
fn exprBody() P.core.Parser(u21) {
    return P.choice(u21, &.{
        P.between(P.char('('), P.recursive(u21, exprBody), P.char(')')),
        P.digit(),
    });
}

test "recursive: balanced parens around a single digit (depth 0)" {
    const expr = comptime P.recursive(u21, exprBody);
    var owned = try expr.runArena("3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u21, '3'), owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.index);
}

test "recursive: balanced parens around a single digit (depth 1)" {
    const expr = comptime P.recursive(u21, exprBody);
    var owned = try expr.runArena("(7)", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u21, '7'), owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "recursive: balanced parens around a single digit (depth 3)" {
    const expr = comptime P.recursive(u21, exprBody);
    var owned = try expr.runArena("(((5)))", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u21, '5'), owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 7), owned.result.ok.index);
}

test "recursive: unbalanced parens — fail at the missing close" {
    const expr = comptime P.recursive(u21, exprBody);
    var owned = try expr.runArena("((5)", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // Expect a char(')') failure — the outer between's right delimiter.
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
}

test "recursive: invalid inner — fail through the recursion" {
    const expr = comptime P.recursive(u21, exprBody);
    var owned = try expr.runArena("(X)", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // Inner choice tries between (which calls recursive again), fails;
    // tries digit, fails. The choice returns the furthest-progress error.
}

test "recursive: composes with .map() to project the recursion's value" {
    const Build = struct {
        fn toBool(cp: u21) bool {
            return cp == '1';
        }
    };
    const expr = comptime P.recursive(u21, exprBody).map(bool, Build.toBool);
    var owned = try expr.runArena("((1))", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(true, owned.result.ok.value);
}
