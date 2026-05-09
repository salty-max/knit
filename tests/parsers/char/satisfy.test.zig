const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

fn isDigit(cp: u21) bool {
    return cp >= '0' and cp <= '9';
}

test "satisfy: matches when predicate returns true" {
    const p = comptime P.satisfy(isDigit, "digit");
    const r = p.run("3 sheep", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, '3'), r.ok.value);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "satisfy: rejects when predicate returns false, parser = supplied name" {
    const p = comptime P.satisfy(isDigit, "digit");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, owned.result.err.kind);
}

test "satisfy: empty input emits incomplete with the supplied parser name" {
    const p = comptime P.satisfy(isDigit, "digit");
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("digit", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "satisfy: mismatch carries actual (the codepoint that failed)" {
    const p = comptime P.satisfy(isDigit, "digit");
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("x", owned.result.err.actual.?);
    // satisfy doesn't expose a structured `expected` (predicate is opaque).
    try std.testing.expect(owned.result.err.expected == null);
}
