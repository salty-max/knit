const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

// File-scope counters mutated by tap callbacks. Reset at the
// start of each test (Zig runs tests sequentially within a file
// by default, so this is safe).
var tap_calls: usize = 0;
var last_seen_index: usize = 0;

fn countingTap(state: *const P.core.ParseState) void {
    tap_calls += 1;
    last_seen_index = state.index;
}

test "tap: side-effect runs once on success" {
    tap_calls = 0;
    last_seen_index = 0;
    const p = comptime P.tap(P.digits(), countingTap);
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), tap_calls);
    // Tap sees the post-parse cursor (digits advanced to 2).
    try std.testing.expectEqual(@as(usize, 2), last_seen_index);
}

test "tap: side-effect runs once on failure" {
    tap_calls = 0;
    last_seen_index = 0;
    const p = comptime P.tap(P.digits(), countingTap);
    const r = p.run("xyz", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(@as(usize, 1), tap_calls);
    // On err, digits leaves cursor at the failing position (0).
    try std.testing.expectEqual(@as(usize, 0), last_seen_index);
}

test "tap: pass-through preserves p's value identity" {
    tap_calls = 0;
    const p = comptime P.tap(P.digits(), countingTap);
    const r = p.run("123abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("123", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "tap: composes inside sequenceOf — runs at the right point" {
    tap_calls = 0;
    last_seen_index = 0;
    const p = comptime P.sequenceOf(.{ P.digits(), P.tap(P.char(' '), countingTap), P.letters() });
    const r = p.run("42 hi", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 1), tap_calls);
    // Tap fires AFTER the space is consumed (cursor at 3).
    try std.testing.expectEqual(@as(usize, 3), last_seen_index);
}
