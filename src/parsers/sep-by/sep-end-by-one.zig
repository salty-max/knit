const core = @import("core");
const internal = @import("internal.zig");

/// One-or-more `p` separated and optionally terminated by `sep`.
/// Same trailing-sep-consumed semantics as `sepEndBy`. Fails with
/// `p`'s own `ParseError` when zero values matched.
///
/// **Allocator note.** Same arena-per-parse expectation as the
/// rest of the `sepBy` family.
///
/// Example:
/// ```zig
/// const list = comptime sepEndByOne(char(','), digit());
/// // list.run("",       a) → err carrying digit's incomplete shape
/// // list.run("1",      a) → ok = .{ .value = .{ '1' },       .index = 1 }
/// // list.run("1,2,3,", a) → ok = .{ .value = .{ '1','2','3' }, .index = 6 }
/// ```
pub fn sepEndByOne(comptime sep: anytype, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const S = @TypeOf(sep).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const collected = internal.collectSepBy(T, S, sep, p, state, true) catch {
                return .{ .err = core.parseError("sepEndByOne", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };
            if (collected.values.len == 0) {
                return .{ .err = collected.last_err.? };
            }
            return core.ok(collected.values, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
