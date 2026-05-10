const std = @import("std");
const core = @import("core");

/// Match `p` between `min` and `max` times (inclusive), collecting
/// values into a `[]T` slice allocated via `state.allocator`. Both
/// bounds are comptime.
///
/// Behavior:
/// - Fewer than `min` matches → fail (with the failing inner
///   parser's err).
/// - Between `min` and `max` matches → ok with the collected slice.
/// - At `max` matches → stop (don't try a (max+1)th attempt).
/// - No-progress break: if `p` succeeds without advancing the
///   cursor (e.g. `succeed`, `lookAhead`), the loop records once
///   and stops to avoid spinning. Mirrors `many`'s contract.
///
/// Compile-time error if `min > max`.
///
/// **Allocator note.** Result slice and the inner parser's
/// transient errors live on `state.allocator`. Use `runArena`
/// for bulk cleanup.
///
/// Example:
/// ```zig
/// const p = comptime repeatBetween(2, 4, digit());
/// // p.run("12345", a) → ok = .{ .value = .{ '1','2','3','4' }, .index = 4 }  (capped at max=4)
/// // p.run("1xyz",  a) → err (only 1 < min=2)
/// ```
pub fn repeatBetween(comptime min: usize, comptime max: usize, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    if (min > max) @compileError("repeatBetween: min must be <= max");
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            // No `errdefer list.deinit` — ParseResult is a plain union;
            // each err branch frees `list` explicitly.
            var list: std.ArrayList(T) = .empty;
            while (list.items.len < max) {
                const before = state.index;
                const r = p.parseFn(state);
                if (r == .err) {
                    state.index = before;
                    if (list.items.len < min) {
                        list.deinit(state.allocator);
                        return .{ .err = r.err };
                    }
                    break;
                }
                list.append(state.allocator, r.ok.value) catch {
                    list.deinit(state.allocator);
                    return .{ .err = core.parseError("repeatBetween", state.index, "out of memory while collecting", .{
                        .kind = .internal,
                    }) };
                };
                if (state.index == before) break;
            }
            const slice: []T = list.toOwnedSlice(state.allocator) catch {
                list.deinit(state.allocator);
                return .{ .err = core.parseError("repeatBetween", state.index, "out of memory while finalizing result slice", .{
                    .kind = .internal,
                }) };
            };
            return core.ok(slice, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
