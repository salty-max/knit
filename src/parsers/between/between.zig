const core = @import("core");

/// Run `left`, then `p`, then `right`, keeping only `p`'s value.
/// Free-function form of `Parser(T).between(left, right)` — same
/// semantics, just spelled out positionally for grammars where
/// `between(L, P, R)` reads more naturally than `P.between(L, R)`.
///
/// Failure of any of the three propagates unchanged with the
/// cursor at the failing position. No backtracking — wrap in
/// `choice` if alternative bracketings need to be tried.
///
/// Pass-through on the parser side — inherits allocator behavior
/// from the inner parsers; `between` itself adds no allocation.
///
/// Types are inferred from the parsers themselves: `between(sep, p, sep)`
/// returns `Parser(@TypeOf(p).Output)`.
///
/// Example:
/// ```zig
/// const expr = comptime between(char('('), digits(), char(')'));
/// // expr.run("(42)abc", a) → ok = .{ .value = "42", .index = 4 }
/// // expr.run("(42",     a) → err carrying char(')')'s incomplete shape
/// ```
pub fn between(comptime left: anytype, comptime p: anytype, comptime right: anytype) core.Parser(@TypeOf(p).Output) {
    return p.between(left, right);
}
