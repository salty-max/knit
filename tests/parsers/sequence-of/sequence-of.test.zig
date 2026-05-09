const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "sequenceOf: 2-tuple of strings" {
    const p = comptime P.sequenceOf(.{ P.str("hello"), P.str(" world") });
    const r = p.run("hello world", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value[0]);
    try std.testing.expectEqualStrings(" world", r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 11), r.ok.index);
}

test "sequenceOf: 3-tuple of mixed slice + slice + slice" {
    const p = comptime P.sequenceOf(.{ P.digits(), P.whitespace1(), P.letters() });
    const r = p.run("12 abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("12", r.ok.value[0]);
    try std.testing.expectEqualStrings(" ", r.ok.value[1]);
    try std.testing.expectEqualStrings("abc", r.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 6), r.ok.index);
}

test "sequenceOf: 5-tuple with mixed value types (u21 + slices)" {
    const p = comptime P.sequenceOf(.{
        P.char('a'),
        P.letters(),
        P.char('-'),
        P.digits(),
        P.char('!'),
    });
    const r = p.run("aXYZ-42!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u21, 'a'), r.ok.value[0]);
    try std.testing.expectEqualStrings("XYZ", r.ok.value[1]);
    try std.testing.expectEqual(@as(u21, '-'), r.ok.value[2]);
    try std.testing.expectEqualStrings("42", r.ok.value[3]);
    try std.testing.expectEqual(@as(u21, '!'), r.ok.value[4]);
    try std.testing.expectEqual(@as(usize, 8), r.ok.index);
}

test "sequenceOf: failure on first parser propagates with cursor at 0" {
    const p = comptime P.sequenceOf(.{ P.str("hello"), P.str(" world") });
    const r = p.run("xyz", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "sequenceOf: failure on middle parser leaves cursor at the failing position" {
    const p = comptime P.sequenceOf(.{ P.str("hello"), P.str(" "), P.str("world") });
    const r = p.run("hello xyz", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("str", r.err.parser);
    try std.testing.expectEqual(@as(usize, 6), r.err.index);
}

test "sequenceOf: failure on last parser also propagates" {
    const p = comptime P.sequenceOf(.{ P.digits(), P.str("END") });
    const r = p.run("123XYZ", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("str", r.err.parser);
    try std.testing.expectEqual(@as(usize, 3), r.err.index);
}

test "sequenceOf: empty input fails on the first inner parser" {
    const p = comptime P.sequenceOf(.{ P.digits(), P.letters() });
    const r = p.run("", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("digits", r.err.parser);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, r.err.kind);
}

test "sequenceOf: TupleResult is a structural tuple type" {
    const Parsers = @TypeOf(.{ P.digits(), P.letters() });
    const Result = P.TupleResult(Parsers);
    // Tuple-style indexing must work; field count must match.
    const ti = @typeInfo(Result);
    try std.testing.expectEqual(@as(usize, 2), ti.@"struct".fields.len);
    try std.testing.expect(ti.@"struct".is_tuple);
}
