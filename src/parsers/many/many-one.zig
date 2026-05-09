const core = @import("core");
const internal = @import("internal.zig");

/// Match `p` one-or-more times, collecting values into a slice
/// allocated via `state.allocator`. Fails if `p` does not match
/// at least once; the failure preserves `p`'s own `ParseError`
/// unchanged so the diagnostic stays precise.
///
/// **No-progress break.** Same as `many`: if `p` succeeds without
/// consuming any input, the loop records once and stops. So
/// `manyOne(succeed(0))` succeeds with a single-element slice and
/// no infinite loop.
///
/// **Allocator note.** The result slice and the inner parser's
/// transient errors are owned by `state.allocator`. Use `runArena`
/// for bulk cleanup.
///
/// Example:
/// ```zig
/// const ds = comptime manyOne(u21, digit());
/// // ds.run("123x", a) → ok = .{ .value = .{ '1','2','3' }, .index = 3 }
/// // ds.run("xyz",  a) → err carrying digit's failure shape
/// ```
pub fn manyOne(comptime T: type, comptime p: core.Parser(T)) core.Parser([]T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const collected = internal.collectMany(T, p, state) catch {
                return .{ .err = core.parseError("manyOne", state.index, "out of memory while collecting", .{
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
