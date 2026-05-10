const core = @import("core");

/// Define a parser that references itself (or another parser
/// that does), enabling recursive grammars without
/// construction-time infinite loops.
///
/// `thunk` is a zero-argument function returning the parser
/// definition. It's invoked **lazily** (each `parse(state)` call
/// re-evaluates it), not at `recursive(...)` construction —
/// which is what breaks the construction-time cycle for grammars
/// like `expr = num | "(" expr ")"`.
///
/// **Caveat: no left recursion.** parsil is a recursive-descent
/// foundation; a left-recursive grammar like `expr = expr "+" num`
/// will infinite-loop at parse time because the parser must
/// consume to advance. Restructure with iteration instead
/// (`many` / `sepBy`) or use right recursion.
///
/// **Perf.** One thunk invocation per `parse(state)` call (the
/// thunk constructs a fresh parser instance each time). The
/// instance is just a struct wrapper around a function pointer,
/// so the cost is constant — no memoization needed for grammars
/// that don't allocate inside the thunk.
///
/// Example — balanced parens around a single digit:
/// ```zig
/// fn exprBody() Parser(u21) {
///     return choice(u21, &.{
///         between(char('('), recursive(u21, exprBody), char(')')),
///         digit(),
///     });
/// }
/// const expr = comptime recursive(u21, exprBody);
/// // expr.run("(((3)))", a) → ok = .{ .value = '3', .index = 7 }
/// ```
pub fn recursive(comptime T: type, comptime thunk: fn () core.Parser(T)) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const inner = thunk();
            return inner.parseFn(state);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
