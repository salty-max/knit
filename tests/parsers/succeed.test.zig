const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "succeed: returns the supplied value at the current cursor" {
    const yes = comptime P.succeed(u32, 42);
    const r = yes.run("anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u32, 42), r.ok.value);
    // Cursor unchanged — succeed doesn't consume input.
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "succeed: works for slice payloads" {
    const yes = comptime P.succeed([]const u8, "default");
    const r = yes.run("ignored", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("default", r.ok.value);
}

test "succeed: composes with .then to inject a value after consuming input" {
    // Parse "key=" then yield a constant value (typical config-default pattern).
    const composed = comptime P.str("key=").then(P.succeed(u32, 100));
    const r = composed.run("key=anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u32, 100), r.ok.value);
    // Cursor is past "key=" (succeed didn't consume but str did).
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}
