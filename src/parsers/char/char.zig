const std = @import("std");
const core = @import("core");
const internal = @import("internal.zig");

/// Match a specific UTF-8 codepoint at the cursor. Advances by the
/// codepoint's byte width on success.
///
/// On mismatch the error carries `expected = "<encoded c>"` and
/// `actual` as a borrowed slice of `state.input` covering the
/// codepoint that was at the cursor (zero allocation; lifetime
/// is the caller's input).
///
/// Example:
/// ```zig
/// const a = comptime char('a');
/// // a.run("apple", alloc) → ok = .{ .value = 'a', .index = 1 }
///
/// const fr = comptime char('é');
/// // fr.run("été", alloc) → ok = .{ .value = 'é', .index = 2 } (2-byte)
/// ```
pub fn char(comptime c: u21) core.Parser(u21) {
    const Thunk = struct {
        // Comptime-encoded UTF-8 bytes for `c`. Lives in the binary
        // alongside other static data; outlives any parse.
        const expected_bytes = blk: {
            var b: [4]u8 = undefined;
            // allow-strict: c is a comptime-known u21 literal; utf8Encode failure is a comptime programming error (surrogate / out-of-range).
            const len = std.unicode.utf8Encode(c, &b) catch unreachable;
            var sized: [len]u8 = undefined;
            for (0..len) |i| sized[i] = b[i];
            break :blk sized;
        };
        const expected_str: []const u8 = &expected_bytes;

        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| return internal.decodeErrorToParseError(err, state.index, "char", expected_str);
            if (decoded.cp != c) {
                return .{ .err = core.parseError("char", state.index, "unexpected codepoint", .{
                    .expected = expected_str,
                    .actual = state.input[state.index..][0..decoded.width],
                    .kind = .syntactic,
                }) };
            }
            state.advance(decoded.width);
            return core.ok(decoded.cp, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
