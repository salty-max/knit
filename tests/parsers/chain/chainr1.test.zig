const std = @import("std");
const P = @import("parsil");

const a = std.testing.allocator;

const Sub = struct {
    fn sub(x: i64, y: i64) i64 {
        return x - y;
    }
};

fn pickMinus(_: u21) *const fn (i64, i64) i64 {
    return &Sub.sub;
}

const minus_op = P.char('-').map(*const fn (i64, i64) i64, pickMinus);

test "chainr1: single operand — returns it unchanged" {
    const expr = comptime P.chainr1(i64, P.intLit(), minus_op);
    var owned = try expr.runArena("42", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(i64, 42), owned.result.ok.value);
}

test "chainr1: 1-2-3 folds right (1-(2-3) = 2)" {
    const expr = comptime P.chainr1(i64, P.intLit(), minus_op);
    var owned = try expr.runArena("1-2-3", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(i64, 2), owned.result.ok.value);
}

test "chainr1: 10-1-1 = 10 (right-assoc: 10-(1-1) = 10)" {
    const expr = comptime P.chainr1(i64, P.intLit(), minus_op);
    var owned = try expr.runArena("10-1-1", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(i64, 10), owned.result.ok.value);
}

test "chainr1: differs from chainl1 on non-associative op" {
    // 1-2-3: chainl1 → -4, chainr1 → 2. Verify the difference holds.
    const expr_l = comptime P.chainl1(i64, P.intLit(), minus_op);
    const expr_r = comptime P.chainr1(i64, P.intLit(), minus_op);
    const r_l = expr_l.run("1-2-3", a);
    var owned_r = try expr_r.runArena("1-2-3", a);
    defer owned_r.deinit();
    try std.testing.expect(r_l == .ok);
    try std.testing.expect(owned_r.result == .ok);
    try std.testing.expectEqual(@as(i64, -4), r_l.ok.value);
    try std.testing.expectEqual(@as(i64, 2), owned_r.result.ok.value);
}

test "chainr1: missing first operand — err" {
    const expr = comptime P.chainr1(i64, P.intLit(), minus_op);
    var owned = try expr.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "chainr1: trailing op without operand — err with cleanup" {
    const expr = comptime P.chainr1(i64, P.intLit(), minus_op);
    var owned = try expr.runArena("1-", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}
