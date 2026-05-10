const std = @import("std");
const core = @import("core");

/// Match one-or-more `(p sep)` pairs — every item REQUIRES a
/// trailing `sep`. Returns a slice of `p`'s values; fails with
/// `p`'s own `ParseError` if zero items match.
///
/// Same semantic as `endBy(sep, p)` but requires ≥1 successful
/// pair. See `endBy` for the family-wide comparison table.
///
/// **Allocator note.** Same arena-per-parse expectation as the
/// rest of the `sepBy` family.
///
/// Example:
/// ```zig
/// const lines = comptime endByOne(char(';'), digits());
/// // lines.run("1;",    a) → ok = .{ .value = .{ "1" },     .index = 2 }
/// // lines.run("1;2;",  a) → ok = .{ .value = .{ "1","2" }, .index = 4 }
/// // lines.run("",      a) → err (digits's incomplete shape)
/// // lines.run("1;2",   a) → err (last item missing terminator)
/// ```
pub fn endByOne(comptime sep: anytype, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            // No `errdefer list.deinit` — ParseResult is a plain union,
            // not an error union; explicit free on each err branch.
            var list: std.ArrayList(T) = .empty;
            var first_err: ?core.ParseError = null;
            while (true) {
                const before_p = state.index;
                const rp = p.parseFn(state);
                if (rp == .err) {
                    state.index = before_p;
                    if (list.items.len == 0) first_err = rp.err;
                    break;
                }
                const rs = sep.parseFn(state);
                if (rs == .err) {
                    list.deinit(state.allocator);
                    return .{ .err = rs.err };
                }
                list.append(state.allocator, rp.ok.value) catch {
                    return .{ .err = core.parseError("endByOne", state.index, "out of memory while collecting", .{
                        .kind = .internal,
                    }) };
                };
                if (state.index == before_p) break;
            }
            if (list.items.len == 0) {
                return .{ .err = first_err.? };
            }
            const slice: []T = list.toOwnedSlice(state.allocator) catch &[_]T{};
            return core.ok(slice, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
