const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "chain: happy path — value flows from p into fn-produced next parser" {
    const Build = struct {
        fn pickStr(d: u21) P.core.Parser([]const u8) {
            return if (d == '1') P.str("one") else P.str("other");
        }
    };
    const p = comptime P.chain(P.digit(), []const u8, Build.pickStr);
    const r = p.run("1one", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("one", r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

test "chain: failure on first parser propagates" {
    const Build = struct {
        fn pickStr(d: u21) P.core.Parser([]const u8) {
            _ = d;
            return P.str("x");
        }
    };
    const p = comptime P.chain(P.digit(), []const u8, Build.pickStr);
    var owned = try p.runArena("xy", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("digit", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "chain: failure on second parser (the fn-produced one) propagates" {
    const Build = struct {
        fn pickStr(d: u21) P.core.Parser([]const u8) {
            _ = d;
            return P.str("EXPECTED");
        }
    };
    const p = comptime P.chain(P.digit(), []const u8, Build.pickStr);
    var owned = try p.runArena("1foo", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 1), owned.result.err.index);
}

test "chain: equivalent to .chain method form" {
    const Build = struct {
        fn pickStr(d: u21) P.core.Parser([]const u8) {
            return if (d == '5') P.str("five") else P.str("nope");
        }
    };
    const free_form = comptime P.chain(P.digit(), []const u8, Build.pickStr);
    const method_form = comptime P.digit().chain([]const u8, Build.pickStr);
    const r1 = free_form.run("5five", a);
    const r2 = method_form.run("5five", a);
    try std.testing.expect(r1 == .ok);
    try std.testing.expect(r2 == .ok);
    try std.testing.expectEqualStrings(r1.ok.value, r2.ok.value);
    try std.testing.expectEqual(r1.ok.index, r2.ok.index);
}

test "chain: typical pattern — tag-dispatched parsing" {
    // The classic value-dependent pattern: a leading tag selects
    // which parser runs next. 'd' → digits, anything else → letters.
    const Build = struct {
        fn dispatch(tag: u21) P.core.Parser([]const u8) {
            return if (tag == 'd') P.digits() else P.letters();
        }
    };
    const p = comptime P.chain(P.anyChar(), []const u8, Build.dispatch);
    var owned1 = try p.runArena("d123!", a);
    defer owned1.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expectEqualStrings("123", owned1.result.ok.value);
    try std.testing.expectEqual(@as(usize, 4), owned1.result.ok.index);
    var owned2 = try p.runArena("labc!", a);
    defer owned2.deinit();
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expectEqualStrings("abc", owned2.result.ok.value);
    try std.testing.expectEqual(@as(usize, 4), owned2.result.ok.index);
}

test "chain: composes inside sequenceOf" {
    const Build = struct {
        fn pickStr(d: u21) P.core.Parser([]const u8) {
            return if (d == '2') P.str("hi") else P.str("bye");
        }
    };
    const inner = comptime P.chain(P.digit(), []const u8, Build.pickStr);
    const p = comptime P.sequenceOf(.{ inner, P.char('!') });
    const r = p.run("2hi!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hi", r.ok.value[0]);
    try std.testing.expectEqual(@as(u21, '!'), r.ok.value[1]);
}
