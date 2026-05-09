const core = @import("core");
const internal = @import("internal.zig");

/// Match `p` zero-or-more times, collecting values into a slice
/// allocated via `state.allocator`. **Always succeeds** — empty
/// input or an immediate failure yields an empty slice with the
/// cursor unchanged.
///
/// **No-progress break.** If `p` succeeds without consuming any
/// input (`succeed`, `lookAhead`, `whitespace()` on a non-whitespace
/// cursor, …), `many` records the value once and stops; otherwise
/// it would loop forever. Mirrors parsil-TS issue #26's fix.
///
/// **Allocator note.** The result slice and the inner parser's
/// transient errors (the last failed attempt) are owned by
/// `state.allocator`. Use the canonical `runArena` so they're
/// freed in bulk on `.deinit()`.
///
/// Example:
/// ```zig
/// const ws = comptime many(char(' '));
/// // ws.run("   hi", a) → ok = .{ .value = .{ ' ', ' ', ' ' }, .index = 3 }
/// // ws.run("hi",    a) → ok = .{ .value = .{},                 .index = 0 }
/// ```
pub fn many(comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const collected = internal.collectMany(T, p, state) catch {
                return .{ .err = core.parseError("many", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };
            return core.ok(collected.values, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
