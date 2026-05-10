const std = @import("std");
const core = @import("core");

/// Match zero-or-more `(p sep)` pairs — every item REQUIRES a
/// trailing `sep`. Returns a slice of `p`'s values.
///
/// Distinct from `sepEndBy(sep, p)` which makes the trailing
/// `sep` optional after the last item: `endBy` rejects an item
/// without its terminator.
///
/// | Combinator | Items | Sep behavior |
/// |---|---|---|
/// | `sepBy(sep, p)` | `p (sep p)*` | between items; trailing sep left in input |
/// | `sepEndBy(sep, p)` | `p (sep p)* sep?` | optional trailing sep consumed |
/// | `endBy(sep, p)` | `(p sep)*` | every item followed by sep; required |
///
/// Failure shapes:
/// - First `p` fails → ok with empty slice (cursor unchanged)
/// - `p` succeeds but `sep` fails → err (incomplete pair)
/// - Subsequent `p` fails after some pairs → ok with what we have,
///   cursor at the failed-`p` position
///
/// **Allocator note.** Result slice and the inner parsers'
/// transient errors live on `state.allocator`. Use `runArena`
/// for bulk cleanup.
///
/// Example:
/// ```zig
/// const lines = comptime endBy(char(';'), digits());
/// // lines.run("1;2;3;", a) → ok = .{ .value = .{ "1","2","3" }, .index = 6 }
/// // lines.run("1;2;3",  a) → err (last item has no trailing ';')
/// // lines.run("",       a) → ok = .{ .value = .{}, .index = 0 }
/// ```
pub fn endBy(comptime sep: anytype, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            // No `errdefer list.deinit` — ParseResult is a plain union,
            // not an error union, so errdefer doesn't fire on the
            // `.err` returns. Each err branch frees `list` explicitly.
            var list: std.ArrayList(T) = .empty;
            while (true) {
                const before_p = state.index;
                const rp = p.parseFn(state);
                if (rp == .err) {
                    state.index = before_p;
                    break;
                }
                const rs = sep.parseFn(state);
                if (rs == .err) {
                    list.deinit(state.allocator);
                    return .{ .err = rs.err };
                }
                list.append(state.allocator, rp.ok.value) catch {
                    return .{ .err = core.parseError("endBy", state.index, "out of memory while collecting", .{
                        .kind = .internal,
                    }) };
                };
                if (state.index == before_p) break;
            }
            const slice: []T = list.toOwnedSlice(state.allocator) catch &[_]T{};
            return core.ok(slice, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
