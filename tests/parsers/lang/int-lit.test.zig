const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "intLit: decimal" {
    const r = P.intLit().run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "intLit: hex (lowercase prefix)" {
    const r = P.intLit().run("0xff", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 255), r.ok.value);
}

test "intLit: hex (uppercase prefix and digits)" {
    const r = P.intLit().run("0XDEAD", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 0xDEAD), r.ok.value);
}

test "intLit: octal" {
    const r = P.intLit().run("0o755", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 493), r.ok.value);
}

test "intLit: binary" {
    const r = P.intLit().run("0b1010", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 10), r.ok.value);
}

test "intLit: stops at non-digit byte" {
    // '0' followed by ' ' is decimal 0, then space.
    const r = P.intLit().run("0 next", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 0), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "intLit: rejects 0x with bad hex digit (identifier boundary)" {
    var owned = try P.intLit().runArena("0x1g", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("intLit", owned.result.err.parser);
}

test "intLit: rejects integer immediately followed by identifier byte" {
    var owned = try P.intLit().runArena("42abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "intLit: empty input is incomplete" {
    const r = P.intLit().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "intLit: rejects digit valid in higher base but not current base" {
    // "0b12" — '1' is binary, '2' is decimal/hex but not binary.
    // The boundary check's second condition fires: '2' is a
    // higher-base digit immediately after a base-2 literal, so
    // we reject rather than silently accepting just "0b1".
    var owned = try P.intLit().runArena("0b12", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "intLit: 0x with no digits (just prefix) — rejected" {
    var owned = try P.intLit().runArena("0x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}
