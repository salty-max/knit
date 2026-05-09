const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "many: zero matches at cursor — empty slice, cursor unchanged" {
    const p = comptime P.many(P.char('a'));
    var owned = try p.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "many: empty input — empty slice" {
    const p = comptime P.many(P.char('a'));
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.value.len);
}

test "many: matches a run, stops on first non-match" {
    const p = comptime P.many(P.char('a'));
    var owned = try p.runArena("aaabc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[0]);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[1]);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[2]);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "many: matches all when input is entirely matchable" {
    const p = comptime P.many(P.digit());
    var owned = try p.runArena("12345", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(usize, 5), owned.result.ok.index);
}

test "many: composes with sequenceOf as a quantified element" {
    const p = comptime P.sequenceOf(.{ P.many(P.char(' ')), P.letters() });
    var owned = try p.runArena("   hello", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value[0].len);
    try std.testing.expectEqualStrings("hello", owned.result.ok.value[1]);
}

test "many: stops on no-progress (inner succeeds without consuming)" {
    // succeed(0) succeeds without advancing the cursor — many must record
    // once and stop, not loop forever.
    const p = comptime P.many(P.succeed(u8, 7));
    var owned = try p.runArena("anything", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.value.len);
    try std.testing.expectEqual(@as(u8, 7), owned.result.ok.value[0]);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "many: returns []T parameterised by inner parser type" {
    const p = comptime P.many(P.str("ab"));
    var owned = try p.runArena("ababab", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value.len);
    try std.testing.expectEqualStrings("ab", owned.result.ok.value[0]);
    try std.testing.expectEqualStrings("ab", owned.result.ok.value[2]);
}

test "many: composes with .map() to project the slice" {
    const Build = struct {
        fn count(s: []u21) usize {
            return s.len;
        }
    };
    const p = comptime P.many(P.char('a')).map(usize, Build.count);
    var owned = try p.runArena("aaab", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.value);
}
