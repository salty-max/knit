const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

// All tests use runArena: choice may swallow sub-parser errors that
// allocated `actual` byte slices via state.allocator (e.g. char('+')
// emits "actual = '-'" when it doesn't match). Without an arena
// owning those allocations, the discarded errors leak — which is
// canonical parsil behavior, not a bug. Arena-per-parse cleans up
// every alternative's transient allocations in bulk on .deinit().

test "choice: first alternative matches, no fall-through" {
    const p = comptime P.choice([]const u8, &.{ P.str("hello"), P.str("hi") });
    var owned = try p.runArena("hello world", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("hello", owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.index);
}

test "choice: middle alternative matches" {
    const p = comptime P.choice(u21, &.{ P.char('+'), P.char('-'), P.char('*') });
    var owned = try p.runArena("-5", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u21, '-'), owned.result.ok.value);
}

test "choice: last alternative matches (full fall-through)" {
    const p = comptime P.choice([]const u8, &.{ P.str("foo"), P.str("bar"), P.str("baz") });
    var owned = try p.runArena("baz!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("baz", owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "choice: total failure returns the furthest-progress error" {
    // str("foobar") will reach index 3 before failing on 'X' at position 3.
    // str("baz") fails at index 0.
    // furthest = err from str("foobar") at index 3.
    const p = comptime P.choice([]const u8, &.{ P.str("baz"), P.str("foobar") });
    var owned = try p.runArena("fooXY", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(@as(usize, 3), owned.result.err.index);
}

test "choice: tie-break favors the earliest alternative" {
    // Both alternatives fail at index 0 on input "z" — neither matches anything.
    // Expected error.parser identifies the FIRST listed alternative (str("a")).
    const p = comptime P.choice([]const u8, &.{ P.str("a"), P.str("b") });
    var owned = try p.runArena("z", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
    try std.testing.expectEqualStrings("a", owned.result.err.expected.?);
}

test "choice: backtracks input position between attempts" {
    // First alt matches 'fo' then fails on 'X' at index 2.
    // Second alt must see cursor restored to 0 and match 'foo'.
    const p = comptime P.choice([]const u8, &.{ P.str("foX"), P.str("foo") });
    var owned = try p.runArena("foobar", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("foo", owned.result.ok.value);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "choice: single-alternative slice is a thin pass-through (success)" {
    const p = comptime P.choice([]const u8, &.{P.str("only")});
    var owned = try p.runArena("only!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("only", owned.result.ok.value);
}

test "choice: single-alternative slice is a thin pass-through (failure)" {
    const p = comptime P.choice([]const u8, &.{P.str("nope")});
    var owned = try p.runArena("xxx", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("nope", owned.result.err.expected.?);
}

test "choice: composes inside sequenceOf" {
    const sign = comptime P.choice(u21, &.{ P.char('+'), P.char('-') });
    const p = comptime P.sequenceOf(.{ sign, P.digits() });
    var owned = try p.runArena("-42", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(u21, '-'), owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("42", owned.result.ok.value[1]);
}

test "choice: composes with .map() to project the alternative" {
    const Build = struct {
        fn isPlus(c: u21) bool {
            return c == '+';
        }
    };
    const p = comptime P.choice(u21, &.{ P.char('+'), P.char('-') }).map(bool, Build.isPlus);
    var owned1 = try p.runArena("+", a);
    defer owned1.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expectEqual(true, owned1.result.ok.value);
    var owned2 = try p.runArena("-", a);
    defer owned2.deinit();
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expectEqual(false, owned2.result.ok.value);
}

test "choice: empty parsers slice triggers a compile error" {
    // Hand-test: uncomment to see the @compileError message.
    // const _ = comptime P.choice([]const u8, &.{});
    // The above must NOT compile, asserting the empty-slice guard.
    return error.SkipZigTest;
}
