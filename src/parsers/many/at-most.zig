const core = @import("core");
const repeat_between = @import("repeat-between.zig");

/// Match `p` at most `n` times. Always succeeds (zero matches OK).
/// Stops after `n` matches even if more would succeed. Same
/// allocator + no-progress semantics as `many`. Compile-time
/// error if `n == 0` (use `succeed(&.{})` instead — trivially
/// always-empty).
///
/// Sugar for `repeatBetween(0, n, p)`.
///
/// Example:
/// ```zig
/// const p = comptime atMost(2, digit());
/// // p.run("12345", a) → ok = .{ .value = .{ '1','2' }, .index = 2 }  (stopped at max)
/// // p.run("",      a) → ok = .{ .value = .{},          .index = 0 }
/// ```
pub fn atMost(comptime n: usize, comptime p: anytype) core.Parser([]@TypeOf(p).Output) {
    if (n == 0) @compileError("atMost: n must be > 0; use `succeed(&[_]T{})` for the always-empty case");
    return repeat_between.repeatBetween(0, n, p);
}
