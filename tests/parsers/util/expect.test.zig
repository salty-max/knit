const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "expect: replaces err.message on failure" {
    const p = comptime P.expect(P.intLit(), "expected port number 0-65535");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("expected port number 0-65535", owned.result.err.message);
}

test "expect: preserves err.parser on failure" {
    const p = comptime P.expect(P.intLit(), "custom msg");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // parser identity is the inner parser's; expect only touches message.
    try std.testing.expectEqualStrings("intLit", owned.result.err.parser);
}

test "expect: preserves err.index and err.kind on failure" {
    const p = comptime P.expect(P.intLit(), "custom msg");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "expect: pass-through on success" {
    const p = comptime P.expect(P.intLit(), "should not surface");
    const r = p.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "expect: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.expect(P.intLit(), "expected int"), P.char(' '), P.identifier() });
    const r = p.run("42 alice", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value[0]);
    try std.testing.expectEqualStrings("alice", r.ok.value[2]);
}
