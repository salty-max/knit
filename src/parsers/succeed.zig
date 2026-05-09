const core = @import("../core.zig");

/// A parser that always succeeds with the supplied `value`, never
/// consuming input. Useful as the identity element in `choice`
/// (last-resort default) and as a value-injector in sequences.
///
/// Example:
/// ```zig
/// const default_42 = comptime succeed(u32, 42);
/// // default_42.run("ignored", a) → .ok = .{ .value = 42, .index = 0 }
/// ```
pub fn succeed(comptime T: type, comptime value: T) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            return core.ok(value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
