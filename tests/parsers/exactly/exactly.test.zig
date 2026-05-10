const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "exactly: n=0 — empty slice, cursor unchanged" {
    const p = comptime P.exactly(0, P.digit());
    var owned = try p.runArena("anything", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "exactly: n=1 — single match" {
    const p = comptime P.exactly(1, P.char('a'));
    var owned = try p.runArena("a", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[0]);
}

test "exactly: n=3 happy path collects three values" {
    const p = comptime P.exactly(3, P.digit());
    var owned = try p.runArena("123xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, '1'), owned.result.ok.value[0]);
    try std.testing.expectEqual(@as(u21, '3'), owned.result.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "exactly: n=3 with only 2 matching — fails on the third attempt at the failing position" {
    // Acceptance criterion from the issue.
    const p = comptime P.exactly(3, P.digit());
    var owned = try p.runArena("12x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 2), owned.result.err.index);
}

test "exactly: n=3 with zero matches — fails on the first attempt" {
    const p = comptime P.exactly(3, P.digit());
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "exactly: n exceeds available input — fails with EOF kind" {
    const p = comptime P.exactly(5, P.digit());
    var owned = try p.runArena("12", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "exactly: works with slice-returning inner ([]const u8)" {
    const p = comptime P.exactly(2, P.str("ab"));
    var owned = try p.runArena("abab!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("ab", owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("ab", owned.result.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.index);
}

test "exactly: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.exactly(3, P.digit()), P.char('!') });
    var owned = try p.runArena("123!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value[0].len);
    try std.testing.expectEqual(@as(u21, '!'), owned.result.ok.value[1]);
}

test "exactly: err path frees the partial buffer (bare allocator, no arena)" {
    // Without the explicit state.allocator.free(buf) on the err branch,
    // this leaks 3*@sizeOf(u21) bytes — std.testing.allocator detects
    // and fails the test. Validates the cleanup contract directly,
    // without an arena masking the bug.
    const p = comptime P.exactly(3, P.digit());
    const r = p.run("12x", a);
    try std.testing.expect(r == .err);
    // r.err.actual (from digit's inner failure) borrows input, not allocator.
    // No defer needed — exactly() owns + freed the buf on the err branch.
}

test "exactly: composes with .map() to count matches" {
    const Build = struct {
        fn count(s: []u21) usize {
            return s.len;
        }
    };
    const p = comptime P.exactly(4, P.digit()).map(usize, Build.count);
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 4), owned.result.ok.value);
}
