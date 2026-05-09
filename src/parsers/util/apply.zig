const core = @import("core");
const sequence_of = @import("../sequence-of/sequence-of.zig");

/// Run a comptime tuple of parsers in order, then apply
/// `fn_apply` to the resulting tuple to produce the final
/// value. Sugar for `sequenceOf(parsers).map(U, fn_apply)` —
/// reads more naturally when the result is a domain-shaped
/// struct built from positional sub-parses.
///
/// Replaces parsil-TS's `coroutine` use cases: a do-notation-
/// like API for "parse N things, then build something from
/// them". Supports any arity (1..N) — the parsers tuple shape
/// determines the function's input shape.
///
/// `fn_apply` takes the same tuple type that `sequenceOf`
/// produces — `TupleResult(@TypeOf(parsers))` — and returns
/// `U`. Failure of any inner parser propagates through the
/// underlying `sequenceOf` (cursor at the failing position;
/// `fn_apply` is not called).
///
/// Example:
/// ```zig
/// const Pair = struct { num: i64, name: []const u8 };
/// const Build = struct {
///     fn make(t: TupleResult(@TypeOf(.{ intLit(), tok(succeed(void, {})), identifier() }))) Pair {
///         return .{ .num = t[0], .name = t[2] };
///     }
/// };
/// const p = comptime apply(.{ intLit(), tok(succeed(void, {})), identifier() }, Pair, Build.make);
/// // p.run("42 alice", a) → ok = .{ .value = .{ .num = 42, .name = "alice" }, ... }
/// ```
pub fn apply(comptime parsers: anytype, comptime U: type, comptime fn_apply: anytype) core.Parser(U) {
    return sequence_of.sequenceOf(parsers).map(U, fn_apply);
}
