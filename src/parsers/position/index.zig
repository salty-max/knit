const core = @import("core");

/// Return the current byte offset (`state.index`) without
/// consuming. Always succeeds. Useful inside `chain` / `apply`
/// to capture positions without going through `withSpan` —
/// pair with another parser to record where a construct
/// starts/ends.
///
/// Pass-through on the cursor; zero allocation.
///
/// Example:
/// ```zig
/// const p = comptime sequenceOf(.{ str("hello"), index() });
/// // p.run("hello world", a) → ok = .{ .value = .{ "hello", 5 }, .index = 5 }
/// ```
pub fn index() core.Parser(usize) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(usize) {
            return core.ok(state.index, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
