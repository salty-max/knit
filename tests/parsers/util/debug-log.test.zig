const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

// debugLog writes to std.debug.print which goes to unbuffered
// stderr. We can't easily capture that from a test (would need
// to swap stderr globally), so these tests verify the parser's
// pass-through behavior rather than the printed content. The
// output itself is human-inspected by running tests with -v.

test "debugLog: passes through p's success unchanged" {
    const p = comptime P.debugLog(P.digits(), "test-num");
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "debugLog: passes through p's failure unchanged" {
    const p = comptime P.debugLog(P.digits(), "test-num");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digits", owned.result.err.parser);
}

test "debugLog: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.debugLog(P.digits(), "n"), P.char(' '), P.debugLog(P.letters(), "id") });
    const r = p.run("42 hi", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("42", r.ok.value[0]);
    try std.testing.expectEqualStrings("hi", r.ok.value[2]);
}

test "debugLog: preserves the inner parser's output type" {
    // debugLog(char(...)) → Parser(u21), not Parser([]const u8).
    const p = comptime P.debugLog(P.char('A'), "letter");
    const r = p.run("A", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'A'), r.ok.value);
}
