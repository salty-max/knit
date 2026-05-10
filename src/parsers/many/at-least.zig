const std = @import("std");
const core = @import("core");
const repeat_between = @import("repeat-between.zig");

/// Match `p` at least `n` times, no upper bound. Fails if fewer
/// than `n` matches. Same allocator + no-progress semantics as
/// `many`. Compile-time error if `n == 0` (use `many` instead).
///
/// Sugar for `repeatBetween(n, std.math.maxInt(usize), p)`.
///
/// Example:
/// ```zig
/// const p = comptime atLeast(2, digit());
/// // p.run("123",   a) → ok = .{ .value = .{ '1','2','3' }, .index = 3 }
/// // p.run("1",     a) → err (only 1 < 2)
/// ```
pub fn atLeast(comptime n: usize, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    if (n == 0) @compileError("atLeast: n must be > 0; use `many` for unbounded zero-or-more");
    return repeat_between.repeatBetween(n, std.math.maxInt(usize), p);
}
