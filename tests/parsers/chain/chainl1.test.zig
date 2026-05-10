const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

const Add = struct {
    fn add(x: i64, y: i64) i64 {
        return x + y;
    }
};
const Sub = struct {
    fn sub(x: i64, y: i64) i64 {
        return x - y;
    }
};

fn pickPlusMinus(c: u21) *const fn (i64, i64) i64 {
    return if (c == '+') &Add.add else &Sub.sub;
}

const plus_or_minus = P.oneOf(&.{ '+', '-' }).map(*const fn (i64, i64) i64, pickPlusMinus);

test "chainl1: single operand — returns it unchanged" {
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    const r = expr.run("42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 42), r.ok.value);
}

test "chainl1: 1-2-3 folds left ((1-2)-3 = -4)" {
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    const r = expr.run("1-2-3", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, -4), r.ok.value);
}

test "chainl1: 10+5-3 = 12" {
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    const r = expr.run("10+5-3", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 12), r.ok.value);
}

test "chainl1: missing first operand — err" {
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    var owned = try expr.runArena("xyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "chainl1: trailing op without operand — err" {
    // After "1+", op succeeded but next intLit fails. Propagates err.
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    var owned = try expr.runArena("1+", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
}

test "chainl1: stops cleanly at first non-op (returns what we have)" {
    // After "1+2", op tries '!' → fails → return acc=3 with cursor at 3.
    const expr = comptime P.chainl1(i64, P.intLit(), plus_or_minus);
    const r = expr.run("1+2!rest", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(i64, 3), r.ok.value);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}
