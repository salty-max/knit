const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "possibly: inner success — ok with Some(value), cursor advanced" {
    const p = comptime P.possibly(P.char('-'));
    const r = p.run("-42", a);
    try std.testing.expect(r == .ok);
    try std.testing.expect(r.ok.value != null);
    try std.testing.expectEqual(@as(u21, '-'), r.ok.value.?);
    try std.testing.expectEqual(@as(usize, 1), r.ok.index);
}

test "possibly: inner failure — ok with null, cursor unchanged" {
    const p = comptime P.possibly(P.char('-'));
    var owned = try p.runArena("42", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "possibly: empty input — ok with null" {
    const p = comptime P.possibly(P.digit());
    var owned = try p.runArena("", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
}

test "possibly: works on slice-returning inner parser" {
    const p = comptime P.possibly(P.digits());
    const r = p.run("123abc", a);
    try std.testing.expect(r == .ok);
    try std.testing.expect(r.ok.value != null);
    try std.testing.expectEqualStrings("123", r.ok.value.?);
    try std.testing.expectEqual(@as(usize, 3), r.ok.index);
}

test "possibly: bit_offset restored when inner fails post-bit-advance (regression)" {
    // Inner reads 3 bits then `.skip(str("X"))` fails. possibly catches
    // the failure and returns null. bit_offset must be restored so a
    // subsequent bit read sees the original cursor.
    //
    // Without the fix: subsequent bitsBe(3) would read bits 3-5 = 0
    // instead of bits 0-2 = 5 from 0xA0.
    const buf = [_]u8{0xA0};
    const opt = comptime P.possibly(P.bit.bitsBe(3).skip(P.str("X")));
    const seq = comptime P.sequenceOf(.{ opt, P.bit.bitsBe(3) });
    const r = seq.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expect(r.ok.value[0] == null);
    try std.testing.expectEqual(@as(u64, 5), r.ok.value[1]);
}

test "possibly: recovered errs from inner-failure are rolled back (regression)" {
    // Inner: recoverAt pushes 1 err, then `.skip(str("ZZZ"))` fails.
    // possibly catches the failure and returns null.
    // Without the fix: the recovered err survives → diag.recovered.len == 1.
    // With the fix: the err is discarded along with the inner's effects → 0.
    const buf = "abc";
    const inner = comptime P.recoverAt(P.str("X"), .{P.peek()}).skip(P.str("ZZZ"));
    const opt = comptime P.possibly(inner);
    var owned = try opt.runDiagArena(buf, a);
    defer owned.deinit();
    try std.testing.expect(owned.diag == .ok);
    try std.testing.expect(owned.diag.ok.value == null);
    try std.testing.expectEqual(@as(usize, 0), owned.diag.ok.recovered.len);
}

test "possibly: rolls back partial inner consumption on failure" {
    // str("foobar") consumes "foo" before failing at index 3.
    // possibly must rewind to index 0 so the cursor reads "fooXY"
    // unchanged for the next parser.
    const p = comptime P.possibly(P.str("foobar"));
    var owned = try p.runArena("fooXY", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "possibly: composes inside sequenceOf for an optional field" {
    // Optional sign followed by required digits.
    // runArena: the no-sign branch runs char('-') against '4', which
    // allocates `actual = '4'` via state.allocator before being
    // discarded by possibly.
    const p = comptime P.sequenceOf(.{ P.possibly(P.char('-')), P.digits() });
    var owned1 = try p.runArena("-42", a);
    defer owned1.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expectEqual(@as(u21, '-'), owned1.result.ok.value[0].?);
    try std.testing.expectEqualStrings("42", owned1.result.ok.value[1]);
    var owned2 = try p.runArena("42", a);
    defer owned2.deinit();
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expect(owned2.result.ok.value[0] == null);
    try std.testing.expectEqualStrings("42", owned2.result.ok.value[1]);
}

test "possibly: composes inside many — collects ?T values" {
    const p = comptime P.many(P.possibly(P.char('a')));
    var owned = try p.runArena("aabxyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    // Two 'a' matches plus one null break — many stops on no-progress
    // when possibly returns null without advancing.
    try std.testing.expect(owned.result.ok.value.len >= 2);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[0].?);
    try std.testing.expectEqual(@as(u21, 'a'), owned.result.ok.value[1].?);
}

test "possibly: composes with .map() to provide a default value" {
    const Build = struct {
        fn defaultZero(opt: ?u21) u21 {
            return opt orelse '0';
        }
    };
    // runArena: the "x" branch makes char('5') fail with an allocated
    // `actual = 'x'` that possibly discards.
    const p = comptime P.possibly(P.char('5')).map(u21, Build.defaultZero);
    var owned1 = try p.runArena("5", a);
    defer owned1.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expectEqual(@as(u21, '5'), owned1.result.ok.value);
    var owned2 = try p.runArena("x", a);
    defer owned2.deinit();
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expectEqual(@as(u21, '0'), owned2.result.ok.value);
}
