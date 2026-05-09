const core = @import("core");
const internal = @import("internal.zig");

/// Match `p` zero-or-more times, separated **and optionally
/// terminated** by `sep`. Always succeeds — empty input yields
/// an empty slice with the cursor unchanged.
///
/// **Trailing separator IS consumed.** If `sep` matches but the
/// following `p` doesn't, the cursor stays *after* the sep so the
/// dangling sep is consumed:
/// `sepEndBy(comma, digit).run("1,2,", a)` → values `["1", "2"]`,
/// cursor at end (index 4).
///
/// **Allocator note.** Same arena-per-parse expectation as `sepBy`.
///
/// Example:
/// ```zig
/// const list = comptime sepEndBy(char(','), digit());
/// // list.run("1,2,3,", a) → ok = .{ .value = .{ '1','2','3' }, .index = 6 }
/// ```
pub fn sepEndBy(comptime sep: anytype, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const S = @TypeOf(sep).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const collected = internal.collectSepBy(T, S, sep, p, state, true) catch {
                return .{ .err = core.parseError("sepEndBy", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };
            return core.ok(collected.values, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
