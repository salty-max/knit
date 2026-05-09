const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "tag: replaces err.parser on failure" {
    const p = comptime P.tag(P.intLit(), "port-number");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("port-number", owned.result.err.parser);
}

test "tag: preserves err.message on failure" {
    const p = comptime P.tag(P.intLit(), "port-number");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // message is the inner parser's; tag only touches parser identity.
    // intLit's message for non-digit is "expected integer digits".
    try std.testing.expectEqualStrings("expected integer digits", owned.result.err.message);
}

test "tag: pass-through on success" {
    const p = comptime P.tag(P.intLit(), "should-not-surface");
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "tag: composes with expect to build a fully customised err" {
    // tag overrides parser identity, expect overrides message.
    // Combined, they replace both fields while preserving index / kind.
    const p = comptime P.tag(P.expect(P.intLit(), "expected integer"), "port-number");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("port-number", owned.result.err.parser);
    try std.testing.expectEqualStrings("expected integer", owned.result.err.message);
}

test "tag: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.tag(P.intLit(), "x"), P.char(' '), P.tag(P.identifier(), "y") });
    const r = p.run("42 alice", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value[0]);
    try std.testing.expectEqualStrings("alice", r.ok.value[2]);
}
