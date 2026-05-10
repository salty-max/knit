const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "fail: emits the supplied ParseError verbatim" {
    const oops = comptime P.fail(P.core.parseError("custom", 5, "boom", .{
        .expected = "x",
        .kind = .semantic,
    }));
    const r = oops.run("anything", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("custom", r.err.parser);
    try std.testing.expectEqual(@as(usize, 5), r.err.index);
    try std.testing.expectEqualStrings("boom", r.err.message);
    try std.testing.expectEqualStrings("x", r.err.expected.?);
    try std.testing.expectEqual(P.core.ParseErrorKind.semantic, r.err.kind);
}

test "fail: cursor stays at the input start (parser doesn't advance)" {
    const oops = comptime P.fail(P.core.parseError("x", 0, "no", .{}));
    const r = oops.run("hello", a);
    try std.testing.expect(r == .err);
    // The error's index reflects the supplied ParseError, not state advance.
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}
