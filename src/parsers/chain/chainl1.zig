const core = @import("core");

/// Left-associative fold over a sequence `operand (op operand)*`.
/// `op` is a parser that produces a binary fold function pointer
/// `*const fn(T, T) T` — typically built via `.map(*const fn(T, T) T, picker)`
/// on an operator-character parser.
///
/// Result is left-folded: `a + b + c + d` becomes
/// `((a + b) + c) + d`.
///
/// Failure shapes:
/// - First `operand` fails → propagates (the chain needs at
///   least one operand)
/// - `op` fails after some operands → return what we have, cursor
///   at the failed-`op` position
/// - `op` succeeds but follow-up `operand` fails → propagate the
///   `operand`'s err (we committed to the operator)
///
/// Zero allocation; pure stack-based fold. Inherits `T` from the
/// `operand` parser; the `op` parser must produce
/// `*const fn(T, T) T` matching the same `T`.
///
/// This is the standard Parsec `chainl1` pattern. For an n-ary
/// precedence grammar, build a tower of `chainl1`/`chainr1` calls
/// — one level per precedence — with operands of inner level being
/// the next level's parser.
///
/// Example (`a - b - c` parses to `(a - b) - c`):
/// ```zig
/// const Sub = struct { fn sub(a: i64, b: i64) i64 { return a - b; } };
/// const minus_op = comptime char('-')
///     .map(*const fn(i64, i64) i64, struct {
///         fn pick(_: u21) *const fn(i64, i64) i64 { return &Sub.sub; }
///     }.pick);
/// const expr = comptime chainl1(i64, intLit(), minus_op);
/// // expr.run("1-2-3", a) → ok = .{ .value = -4, .index = 5 } (left-assoc: (1-2)-3 = -4)
/// ```
pub fn chainl1(
    comptime T: type,
    comptime operand: core.Parser(T),
    comptime op: core.Parser(*const fn (T, T) T),
) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r0 = operand.parseFn(state);
            if (r0 == .err) return .{ .err = r0.err };
            var acc: T = r0.ok.value;
            while (true) {
                const before_op = state.index;
                const ro = op.parseFn(state);
                if (ro == .err) {
                    state.index = before_op;
                    break;
                }
                const r1 = operand.parseFn(state);
                if (r1 == .err) return .{ .err = r1.err };
                acc = ro.ok.value(acc, r1.ok.value);
                if (state.index == before_op) break;
            }
            return core.ok(acc, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
