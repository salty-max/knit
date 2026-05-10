const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "manyOne: matches a single element" {
    const p = comptime P.manyOne(P.char('a'));
    var owned = try p.runArena("a", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[0]);
}

test "manyOne: matches a run, stops on first non-match" {
    const p = comptime P.manyOne(P.char('a'));
    var owned = try p.runArena("aaabc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "manyOne: zero matches at cursor — fails with inner's error" {
    const p = comptime P.manyOne(P.char('a'));
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "manyOne: empty input — fails with inner's incomplete kind" {
    const p = comptime P.manyOne(P.char('a'));
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, owned.result.err.kind);
}

test "manyOne: succeed inner — single element, no infinite loop" {
    const p = comptime P.manyOne(P.succeed(u8, 99));
    var owned = try p.runArena("anything", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u8, 99), owned.result.ok.value[0]);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "manyOne: composes inside sequenceOf" {
    const p = comptime P.sequenceOf(.{ P.manyOne(P.digit()), P.char('!') });
    var owned = try p.runArena("42!", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.value[0].len);
    try std.testing.expectEqual(@as(u21, '!'), owned.result.ok.value[1]);
}

test "manyOne: composes with .map() to count matches" {
    const Build = struct {
        fn count(s: []u21) usize {
            return s.len;
        }
    };
    const p = comptime P.manyOne(P.digit()).map(usize, Build.count);
    var owned = try p.runArena("12345abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.value);
}
