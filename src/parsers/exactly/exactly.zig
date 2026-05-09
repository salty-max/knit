const core = @import("core");

/// Match `p` exactly `n` times, collecting values into a slice
/// allocated via `state.allocator`. Disambiguates from `many`
/// (zero+) and `manyOne` (one+) — the bound is exact, not min/max.
///
/// `n = 0` is a trivial success: returns an empty slice with the
/// cursor unchanged. `n` is comptime — the parser kernel is
/// monomorphic on `n` so the loop bound is inlinable; for
/// runtime-driven repetition use `many` plus an external check
/// on the result length.
///
/// On the (k+1)th attempt's failure, returns the inner err
/// unchanged with the cursor at the failing position. The first
/// `k` matches' allocations are reclaimed before returning.
///
/// **Allocator note.** Pre-allocates `n * @sizeOf(T)` bytes once
/// (single alloc, no growth) — cheaper than `many`'s growable
/// `ArrayList` when the count is known. Same arena-per-parse
/// expectation; on err the buffer is freed via direct
/// `state.allocator.free` (arena: no-op).
///
/// Example:
/// ```zig
/// const triple = comptime exactly(3, digit());
/// // triple.run("123abc", a) → ok = .{ .value = .{ '1','2','3' }, .index = 3 }
/// // triple.run("12abc",  a) → err carrying digit's syntactic shape, cursor 2
/// ```
pub fn exactly(comptime n: usize, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]T) {
            const buf = state.allocator.alloc(T, n) catch {
                return .{ .err = core.parseError("exactly", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };
            for (0..n) |i| {
                const r = p.parseFn(state);
                if (r == .err) {
                    state.allocator.free(buf);
                    return .{ .err = r.err };
                }
                buf[i] = r.ok.value;
            }
            return core.ok(buf, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
