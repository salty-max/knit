const core = @import("core");

/// Run `p`, call `fn_tap(state)` for side-effects, then return
/// `p`'s result unchanged. The "instrumentation seam" — drop in
/// to log, count, or assert at any point in a grammar without
/// changing semantics.
///
/// `fn_tap` runs **after** `p` regardless of `p`'s outcome (ok
/// or err). It receives a `*const ParseState` so it can read
/// the cursor / input but not mutate them — preserving the
/// "tap doesn't modify state" contract. The state-mutation
/// `p` already performed (advancing on success, leaving cursor
/// at the failing position on err) is visible to `fn_tap`.
///
/// Pure pass-through on the parser side: zero allocation, zero
/// type change. `fn_tap`'s side-effects (printing, counter
/// increments, etc.) are entirely the caller's responsibility.
///
/// Example:
/// ```zig
/// fn logCursor(state: *const ParseState) void {
///     std.log.debug("cursor at {d}", .{state.index});
/// }
/// const p = comptime tap(digits(), logCursor);
/// // p.run("42", a) → ok = .{ .value = "42", .index = 2 }
/// //                  (and logCursor was called once)
/// ```
pub fn tap(
    comptime p: anytype,
    comptime fn_tap: fn (*const core.ParseState) void,
) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            fn_tap(state);
            return r;
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
