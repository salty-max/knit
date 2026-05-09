const core = @import("core");
const internal = @import("internal.zig");

/// Match `p` zero-or-more times, separated by `sep`. Always
/// succeeds — empty input or an immediate failure of the first
/// `p` yields an empty slice with the cursor unchanged.
///
/// **No trailing separator.** If `sep` matches but the following
/// `p` doesn't, the cursor rolls back to the separator's position
/// so the dangling sep is left for the next parser:
/// `sepBy(comma, digit).run("1,2,", a)` → values `["1", "2"]`,
/// cursor at the trailing `,` (index 3, not 4).
///
/// **Allocator note.** Result slice and the inner parsers'
/// transient errors live on `state.allocator`. Use `runArena` for
/// bulk cleanup.
///
/// Example:
/// ```zig
/// const list = comptime sepBy(char(','), digit());
/// // list.run("1,2,3", a) → ok = .{ .value = .{ '1','2','3' }, .index = 5 }
/// ```
pub fn sepBy(comptime sep: anytype, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const S = @TypeOf(sep).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const collected = internal.collectSepBy(T, S, sep, p, state, false) catch {
                return .{ .err = core.parseError("sepBy", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };
            return core.ok(collected.values, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
