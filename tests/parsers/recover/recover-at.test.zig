const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "recoverAt: p succeeds — Some(value), cursor at end of p" {
    const p = comptime P.recoverAt(P.str("hello"), .{P.endOfInput()});
    const r = p.run("hello world", a);
    try std.testing.expect(r == .ok);
    try std.testing.expect(r.ok.value != null);
    try std.testing.expectEqualStrings("hello", r.ok.value.?);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "recoverAt: p fails, anchor matches forward — null + recovery cursor" {
    // p tries 'X', fails at index 0. Scan: at 0 char(';') fails, advance.
    // At 1 ';' matches. Return null with cursor at 1 (anchor not consumed).
    const p = comptime P.recoverAt(P.char('X'), .{P.char(';')});
    var owned = try p.runArena("a;rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.index);
}

test "recoverAt: anchor at start — null at index 0" {
    // p fails immediately; anchor matches at the same position.
    const p = comptime P.recoverAt(P.char('X'), .{P.char('a')});
    var owned = try p.runArena("a;rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 0), owned.result.ok.index);
}

test "recoverAt: heterogeneous tuple of anchors — Parser(u21) + Parser(void) mixed" {
    // First anchor (char('X')) returns u21; second (endOfInput) returns void.
    // The tuple form lets them coexist — only success/failure matters.
    const p = comptime P.recoverAt(P.char('Z'), .{ P.char('X'), P.endOfInput() });
    var owned = try p.runArena("aaa", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    // Neither 'X' anywhere; endOfInput catches at index 3.
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "recoverAt: multiple anchors, second one matches at a forward position" {
    // First anchor (char('X')) won't match — input has no 'X'. Second
    // anchor (char(';')) matches at position 1.
    const p = comptime P.recoverAt(P.char('Z'), .{ P.char('X'), P.char(';') });
    var owned = try p.runArena("a;rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 1), owned.result.ok.index);
}

test "recoverAt: no anchor matches before EOF — original err propagates" {
    const p = comptime P.recoverAt(P.char('X'), .{P.char(';')});
    var owned = try p.runArena("abcdef", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    // Original err is from char('X')'s failure at index 0.
    try std.testing.expectEqualStrings("char", owned.result.err.parser);
    try std.testing.expectEqual(@as(usize, 0), owned.result.err.index);
}

test "recoverAt: endOfInput as anchor catches at EOF" {
    const p = comptime P.recoverAt(P.char('X'), .{P.endOfInput()});
    var owned = try p.runArena("abc", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "recoverAt: scans from where p left off, not from start" {
    // p = sequenceOf(.{ digits(), char('!') }) consumes "12" then fails
    // on ';'. Cursor after p failure should be at 2. Anchor char(';')
    // at position 2 matches immediately. Result: null, cursor 2.
    const stmt = comptime P.sequenceOf(.{ P.digits(), P.char('!') });
    const p = comptime P.recoverAt(stmt, .{P.char(';')});
    var owned = try p.runArena("12;rest", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.index);
}

test "recoverAt: anchor cursor is at the recovery point, not past the anchor" {
    // The anchor is NOT consumed — the cursor lands AT the anchor's
    // match-start. Caller chains .skip(anchor) to consume.
    const p = comptime P.recoverAt(P.char('X'), .{P.str(";END")});
    var owned = try p.runArena("ab;ENDxyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqual(@as(usize, 2), owned.result.ok.index);
}

test "recoverAt: bit_offset restored after anchor-scan recovery (regression)" {
    // Inner fails on str("X") at byte 0. Anchor (peek) matches.
    // recoverAt's scan loop saves/restores bit_offset around each anchor
    // attempt — without the fix, a subsequent bit read would see corrupted
    // bit_offset state.
    //
    // Setup: subsequent bitsBe(3) must read bits 0-2 = 5 from 0xA0.
    const buf = [_]u8{0xA0};
    const recovered = comptime P.recoverAt(P.str("X"), .{P.peek()});
    const seq = comptime P.sequenceOf(.{ recovered, P.bit.bitsBe(3) });
    const r = seq.run(&buf, a);
    try std.testing.expect(r == .ok);
    try std.testing.expect(r.ok.value[0] == null);
    try std.testing.expectEqual(@as(u64, 5), r.ok.value[1]);
}

test "recoverAt: rolls back partial anchor consumption between scan positions" {
    // Anchor = str("END") tried at each scan position. On "ENXENDxyz":
    // pos 0: str("END") matches 'E', 'N', then fails on 'X' (str leaves
    //        cursor at 2 post-partial-match). Restore must bring cursor
    //        back to 0; otherwise the next iter advances from 2 and we
    //        miss the real "END" at position 3.
    const p = comptime P.recoverAt(P.char('Z'), .{P.str("END")});
    var owned = try p.runArena("ENXENDxyz", a);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expect(owned.result.ok.value == null);
    try std.testing.expectEqual(@as(usize, 3), owned.result.ok.index);
}

test "recoverAt: composes with .map() to flatten the optional" {
    // A common downstream pattern: if recovered, replace null with a
    // sentinel value to keep the rest of the grammar happy.
    const Build = struct {
        fn defaultEmpty(opt: ?[]const u8) []const u8 {
            return opt orelse "";
        }
    };
    const p = comptime P.recoverAt(P.str("hello"), .{P.endOfInput()}).map([]const u8, Build.defaultEmpty);
    var owned1 = try p.runArena("hello world", a);
    defer owned1.deinit();
    try std.testing.expect(owned1.result == .ok);
    try std.testing.expectEqualStrings("hello", owned1.result.ok.value);
    var owned2 = try p.runArena("badbad", a);
    defer owned2.deinit();
    try std.testing.expect(owned2.result == .ok);
    try std.testing.expectEqualStrings("", owned2.result.ok.value);
}
