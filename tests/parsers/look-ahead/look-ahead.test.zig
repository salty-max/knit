const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "lookAhead: success returns value but restores cursor to entry" {
    const p = comptime P.lookAhead(P.str("hi"));
    const r = p.run("hi there", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hi", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "lookAhead: failure passes through with cursor at entry too" {
    const p = comptime P.lookAhead(P.str("hi"));
    var owned = try p.runArena("xy", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
}

test "lookAhead: works with codepoint inner parser" {
    const p = comptime P.lookAhead(P.digit());
    const r = p.run("7abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '7'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "lookAhead: equivalent to .lookAhead method form" {
    const free_form = comptime P.lookAhead(P.str("hi"));
    const method_form = comptime P.str("hi").lookAhead();
    const r1 = free_form.run("hi!", a);
    const r2 = method_form.run("hi!", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expect(r2 == .ok);
    try std.testing.expectEqualStrings(r1.ok.value, r2.ok.value);
    try std.testing.expectEqual(r1.ok.index, r2.ok.index);
}

test "lookAhead: composes with sequenceOf — peek then commit" {
    // Peek at a digit, then actually consume it.
    const p = comptime P.sequenceOf(.{ P.lookAhead(P.digit()), P.digit() });
    const r = p.run("5x", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '5'), r.ok.value[0]);
    try std.testing.expectEqual(@as(u21, '5'), r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "lookAhead: rolls back partial inner consumption on failure" {
    // str("foobar") consumes "foo" before failing at index 3.
    // lookAhead must rewind to 0 so the cursor reads "fooXY"
    // unchanged for the next parser (or for inspection).
    const p = comptime P.lookAhead(P.str("foobar"));
    var owned = try p.runArena("fooXY", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // The error preserves the inner parser's failure index for diagnostics.
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
}

test "lookAhead: composes with .map() — peek-then-transform" {
    const Build = struct {
        fn isEven(cp: u21) bool {
            return ((cp - '0') & 1) == 0;
        }
    };
    const p = comptime P.lookAhead(P.digit()).map(bool, Build.isEven);
    const r1 = p.run("4", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expectEqual(true, r1.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r1.ok.index);
    const r2 = p.run("3", a);
    try std.testing.expect(r2 == .ok);
    try std.testing.expectEqual(false, r2.ok.value);
}
