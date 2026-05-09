const std = @import("std");
const core = @import("../core.zig");

/// Match the literal `target` at the current cursor.
///
/// On success: returns the matched slice (which equals `target`) and
/// advances the cursor by `target.len`. The slice is borrowed from
/// the input — no allocation.
///
/// On failure: emits a `ParseError` with `parser = "str"`. If the
/// input runs out before the literal is matched, the error's
/// `expected` is `target` and `actual` is the consumed prefix.
/// If the prefix differs, the error sits at the start position
/// with `expected = target` and `actual` is the candidate slice.
///
/// Example:
/// ```zig
/// const r = str("hello").run("hello world");
/// // r.ok.value == "hello", r.ok.index == 5
/// ```
pub fn str(comptime target: []const u8) core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            const rem = state.remaining();
            if (rem.len < target.len) {
                var matched: usize = 0;
                while (matched < rem.len and rem[matched] == target[matched]) : (matched += 1) {}
                return .{ .err = core.parseError(
                    "str",
                    state.index + matched,
                    "unexpected end of input",
                    .{ .expected = target, .actual = rem, .kind = .incomplete },
                ) };
            }

            // Annotate the slice type explicitly so `core.ok(cand, ...)`'s
            // anytype-inferred T resolves to []const u8 (Zig's bounded
            // slice expression otherwise produces *const [N]u8).
            const cand: []const u8 = rem[0..target.len];
            if (!std.mem.eql(u8, cand, target)) {
                return .{ .err = core.parseError(
                    "str",
                    state.index,
                    "expected literal",
                    .{ .expected = target, .actual = cand },
                ) };
            }

            state.advance(target.len);
            return core.ok(cand, state.index);
        }
    };

    return .{ .parseFn = &Thunk.parse };
}
