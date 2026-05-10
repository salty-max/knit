const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "everythingUntil: stops just before stopP match" {
    const p = comptime P.everythingUntil(P.char(']'));
    const r = p.run("abc]xyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("abc", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "everythingUntil: stopP matches at start — empty slice, cursor 0" {
    const p = comptime P.everythingUntil(P.char('a'));
    const r = p.run("abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "everythingUntil: stopP matches at end — full prefix consumed" {
    const p = comptime P.everythingUntil(P.char('z'));
    const r = p.run("abcz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("abc", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "everythingUntil: EOF without stopP — err with incomplete kind" {
    const p = comptime P.everythingUntil(P.char(']'));
    const r = p.run("abcXY", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("everythingUntil", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
    try std.testing.expectEqual(@as(usize, 5), r.err.index);
}

test "everythingUntil: empty input + non-matching stopP — incomplete" {
    const p = comptime P.everythingUntil(P.char(']'));
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "everythingUntil: empty input + always-succeeding stopP — ok empty" {
    const p = comptime P.everythingUntil(P.startOfInput());
    const r = p.run("", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
}

test "everythingUntil: works with multi-char stopP (str)" {
    const p = comptime P.everythingUntil(P.str("END"));
    const r = p.run("hello world ENDxyz", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello world ", r.ok.value);
    try std.testing.expectEqual(@as(usize, 12), r.ok.index);
}

test "everythingUntil: result is a borrow into input (zero copy)" {
    const p = comptime P.everythingUntil(P.char('|'));
    const input = "abc|xyz";
    const r = p.run(input, a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@intFromPtr(input.ptr), @intFromPtr(r.ok.value.ptr));
}

test "everythingUntil: rolls back partial stopP consumption between attempts" {
    // Input: "ENNDEND". At position 0, str("END") matches 'E', then
    // fails on 'N' (expected 'D'). The cursor advances internally
    // before failing, so the test verifies our explicit
    // `state.index = saved` restore — without it, byte 'N' at
    // position 1 would be skipped and the loop would diverge.
    const p = comptime P.everythingUntil(P.str("END"));
    const r = p.run("ENNDEND", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("ENND", r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "everythingUntil: composes inside sequenceOf — body then stop marker" {
    const p = comptime P.sequenceOf(.{ P.everythingUntil(P.char(';')), P.char(';') });
    const r = p.run("alpha;beta", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("alpha", r.ok.value[0]);
    try std.testing.expectEqual(@as(u21, ';'), r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 6), r.ok.index);
}
