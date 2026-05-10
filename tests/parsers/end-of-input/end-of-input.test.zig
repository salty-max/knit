const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "endOfInput: empty input — ok at index 0" {
    const p = comptime P.endOfInput();
    const r = p.run("", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "endOfInput: leftover input — err with parser identity" {
    const p = comptime P.endOfInput();
    const r = p.run("xy", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("endOfInput", r.err.parser);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "endOfInput: actual borrows the leftover prefix" {
    const p = comptime P.endOfInput();
    const r = p.run("abcdef", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("abcdef", r.err.actual.?);
}

test "endOfInput: actual is capped at 16 bytes for long leftovers" {
    const p = comptime P.endOfInput();
    // 20-byte input — preview should show the first 16.
    const r = p.run("aaaaaaaaaaaaaaaaaaaa", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(@as(usize, 16), r.err.actual.?.len);
    try std.testing.expectEqualStrings("aaaaaaaaaaaaaaaa", r.err.actual.?);
}

test "endOfInput: cursor at end after a previous parse — ok" {
    const p = comptime P.digits().skip(P.endOfInput());
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "endOfInput: cursor not at end after a previous parse — err" {
    const p = comptime P.digits().skip(P.endOfInput());
    const r = p.run("42!", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("endOfInput", r.err.parser);
    try std.testing.expectEqual(@as(usize, 2), r.err.index);
    try std.testing.expectEqualStrings("!", r.err.actual.?);
}

test "endOfInput: composes inside sequenceOf as a void terminator" {
    const p = comptime P.sequenceOf(.{ P.letters(), P.endOfInput() });
    const r = p.run("hello", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value[0]);
    // value[1] is void — no meaningful field to assert beyond ok status.
}

test "endOfInput: zero allocation on err path" {
    // The whole point of borrow-from-input: this test uses the bare
    // testing allocator with no arena and no leak detection issue.
    const p = comptime P.endOfInput();
    const r = p.run("leftover bytes here", a);
    try std.testing.expect(r == .err);
    // No defer / no arena needed — actual is borrowed from input.
}

test "endOfInput: actual is a SLICE of the input, not a copy" {
    // The "borrowed from input" claim isn't visible from
    // expectEqualStrings — content matches either way. Pointer
    // identity is the test that actually proves zero allocation.
    const p = comptime P.endOfInput();
    const input = "leftover";
    const r = p.run(input, a);
    try std.testing.expect(r == .err);
    // actual.ptr must point into the original input, not a fresh allocation.
    try std.testing.expectEqual(@intFromPtr(input.ptr), @intFromPtr(r.err.actual.?.ptr));
}
