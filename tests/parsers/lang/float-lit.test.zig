const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "floatLit: decimal with fraction" {
    const r = P.floatLit().run("3.14", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f64, 3.14), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "floatLit: integer with exponent" {
    const r = P.floatLit().run("1e10", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f64, 1e10), r.ok.value);
}

test "floatLit: fraction + signed exponent" {
    const r = P.floatLit().run("2.5e-3", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0025), r.ok.value, 1e-12);
}

test "floatLit: uppercase E" {
    const r = P.floatLit().run("1.5E2", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(f64, 150.0), r.ok.value);
}

test "floatLit: bare integer falls through (no fraction or exponent)" {
    var owned = try P.floatLit().runArena("42", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "floatLit: empty input is incomplete" {
    const r = P.floatLit().run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "floatLit: rejects float followed by identifier byte" {
    var owned = try P.floatLit().runArena("3.14foo", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "floatLit: dot with no fractional digits — backs out the dot" {
    // "3.foo" — the '.' has no digits after it. floatLit backs out
    // the dot, sees no exponent either, fails (no fraction/exponent).
    var owned = try P.floatLit().runArena("3.foo", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "floatLit: 'e' with no exponent digits — backs out the 'e'" {
    // "3eX" — the 'e' has no digits after it. floatLit backs out
    // the 'e', sees no fraction either, fails.
    var owned = try P.floatLit().runArena("3eX", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}
