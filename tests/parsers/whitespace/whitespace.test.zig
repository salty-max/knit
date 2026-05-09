const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "whitespace: empty input is ok with empty slice, cursor 0" {
    const p = comptime P.whitespace();
    const r = p.run("", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "whitespace: non-whitespace cursor is ok with empty slice, cursor 0" {
    const p = comptime P.whitespace();
    const r = p.run("xy", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "whitespace: matches a run of spaces" {
    const p = comptime P.whitespace();
    const r = p.run("   hi", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("   ", r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "whitespace: preserves tabs and newlines in the slice" {
    const p = comptime P.whitespace();
    const r = p.run("\t \n\rabc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("\t \n\r", r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "whitespace: preserves CRLF byte pair verbatim" {
    const p = comptime P.whitespace();
    const r = p.run("\r\nx", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("\r\n", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "whitespace: matches all when input is entirely whitespace" {
    const p = comptime P.whitespace();
    const r = p.run("   \n\t", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("   \n\t", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "whitespace: vertical tab is NOT recognised" {
    const p = comptime P.whitespace();
    const r = p.run("\x0Bxx", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}
