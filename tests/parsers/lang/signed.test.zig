const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "signed(intLit): negative integer" {
    const r = P.signed(P.intLit()).run("-42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -42), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "signed(intLit): explicit positive sign" {
    const r = P.signed(P.intLit()).run("+42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "signed(intLit): no sign — passes through" {
    const r = P.signed(P.intLit()).run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "signed(intLit): negative hex" {
    const r = P.signed(P.intLit()).run("-0xff", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -255), r.ok.value);
}

test "signed(floatLit): negative float with exponent" {
    const r = P.signed(P.floatLit()).run("-2.5e-3", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectApproxEqAbs(@as(f64, -0.0025), r.ok.value, 1e-12);
}

test "signed(intLit): inner failure propagates after sign consumed" {
    // '-' consumed, then intLit fails on 'x'. Cursor at 1 (post-sign).
    var owned = try P.signed(P.intLit()).runArena("-x", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("intLit", owned.result.err.parser);
}

test "signed(intLit): empty input is incomplete (inner's err)" {
    const r = P.signed(P.intLit()).run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}
