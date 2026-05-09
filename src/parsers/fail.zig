const core = @import("core");

/// A parser that always fails with the supplied `ParseError`.
///
/// Returns `Parser(noreturn)` because there is no successful payload
/// to constrain — the union's `.ok` arm is unreachable. `noreturn`
/// composes with other parsers in `choice` and similar combinators
/// without forcing a concrete `T`.
///
/// Example:
/// ```zig
/// const oops = comptime fail(core.parseError("custom", 0, "boom", .{}));
/// _ = oops.run("anything", allocator); // → .err with the supplied ParseError
/// ```
pub fn fail(comptime e: core.ParseError) core.Parser(noreturn) {
    const Thunk = struct {
        fn parse(_: *core.ParseState) core.ParseResult(noreturn) {
            return .{ .err = e };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
