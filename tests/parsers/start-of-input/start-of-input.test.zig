const std = @import("std");
const P = @import("knit");

const a = std.testing.allocator;

test "startOfInput: at start — ok at index 0" {
    const p = comptime P.startOfInput();
    const r = p.run("anything", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "startOfInput: empty input is also at start" {
    const p = comptime P.startOfInput();
    const r = p.run("", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "startOfInput: after consumption — err with violation index" {
    // Sequence: parse two chars, then try startOfInput — must fail
    // because cursor is at index 2.
    const p = comptime P.sequenceOf(.{ P.letters(), P.startOfInput() });
    const r = p.run("hi", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("startOfInput", r.err.parser);
    try std.testing.expectEqual(@as(usize, 2), r.err.index);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, r.err.kind);
}

test "startOfInput: composes inside sequenceOf as a leading guard" {
    // The common shebang-like pattern: assert at start, then parse content.
    const p = comptime P.sequenceOf(.{ P.startOfInput(), P.str("#!") });
    const r = p.run("#!/bin/sh", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("#!", r.ok.value[1]);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "startOfInput: zero allocation on err path" {
    // No actual slice, no allocation. Bare allocator suffices.
    const p = comptime P.sequenceOf(.{ P.letters(), P.startOfInput() });
    const r = p.run("xyz", a);
    try std.testing.expect(r == .err);
    // No defer / no arena needed — startOfInput err has no allocations.
}

test "startOfInput: works inside lookAhead — peek-position-only" {
    // Wrap startOfInput in lookAhead for a non-consuming position assertion.
    // At the start, both succeed without advancing.
    const p = comptime P.lookAhead(P.startOfInput());
    const r = p.run("data", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "startOfInput: composes via .then to discard the void and keep payload" {
    // The doc-comment example: assert at start, then keep the parsed payload.
    // .then is the more common idiom than sequenceOf for this pattern.
    const shebang = comptime P.startOfInput().then(P.str("#!"));
    const r = shebang.run("#!/bin/sh\n", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("#!", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "startOfInput: err carries no actual field (none meaningful)" {
    // Distinct from endOfInput which previews the leftover. startOfInput
    // can't preview meaningfully — the violating position is just an
    // index into input the caller already holds.
    const p = comptime P.sequenceOf(.{ P.char('a'), P.startOfInput() });
    const r = p.run("a", a);
    try std.testing.expect(r == .err);
    try std.testing.expect(r.err.actual == null);
}
