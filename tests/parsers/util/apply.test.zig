const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

test "apply: arity 1 — single parser, single value into fn" {
    const Build = struct {
        fn double(t: P.TupleResult(@TypeOf(.{P.intLit()}))) i64 {
            return t[0] * 2;
        }
    };
    const p = comptime P.apply(.{P.intLit()}, i64, Build.double);
    const r = p.run("21", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "apply: arity 2 — pair into a struct" {
    const Pair = struct { num: i64, name: []const u8 };
    const Build = struct {
        fn make(t: P.TupleResult(@TypeOf(.{ P.intLit(), P.tok(P.succeed(u8, 0)) }))) Pair {
            // tok(succeed(...)) acts as a whitespace-eater here.
            _ = t[1];
            return .{ .num = t[0], .name = "ignored" };
        }
    };
    const p = comptime P.apply(.{ P.intLit(), P.tok(P.succeed(u8, 0)) }, Pair, Build.make);
    const r = p.run("42  ", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value.num);
}

test "apply: arity 3 — int + sep + identifier" {
    const Pair = struct { num: i64, name: []const u8 };
    const Build = struct {
        fn make(t: P.TupleResult(@TypeOf(.{ P.intLit(), P.char(' '), P.identifier() }))) Pair {
            return .{ .num = t[0], .name = t[2] };
        }
    };
    const p = comptime P.apply(.{ P.intLit(), P.char(' '), P.identifier() }, Pair, Build.make);
    const r = p.run("42 alice", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value.num);
    try std.testing.expectEqualStrings("alice", r.ok.value.name);
}

test "apply: arity 5 — kitchen sink" {
    // (digits, char, digits, char, digits) → sum
    const Build = struct {
        fn sum(t: P.TupleResult(@TypeOf(.{ P.intLit(), P.char(','), P.intLit(), P.char(','), P.intLit() }))) i64 {
            return t[0] + t[2] + t[4];
        }
    };
    const p = comptime P.apply(
        .{ P.intLit(), P.char(','), P.intLit(), P.char(','), P.intLit() },
        i64,
        Build.sum,
    );
    const r = p.run("1,2,3", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 6), r.ok.value);
}

test "apply: failure of inner propagates without calling fn" {
    // If fn was called with undefined values, this would crash or
    // return garbage. The test passes because apply short-circuits
    // through sequenceOf's failure path before invoking map.
    const Build = struct {
        fn unsafeMul(t: P.TupleResult(@TypeOf(.{ P.intLit(), P.intLit() }))) i64 {
            return t[0] * t[1];
        }
    };
    const p = comptime P.apply(.{ P.intLit(), P.intLit() }, i64, Build.unsafeMul);
    var owned = try p.runArena("42 noint", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}
