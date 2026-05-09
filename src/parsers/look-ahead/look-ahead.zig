const core = @import("core");

/// Run `p` without committing — non-consuming success, error
/// passes through with the cursor restored. Free-function form
/// of `Parser(T).lookAhead()`; same semantics, just spelled
/// positionally for grammars where `lookAhead(P)` reads more
/// naturally than `P.lookAhead()`.
///
/// Use to peek at upcoming structure (e.g. distinguish `let` from
/// `letter` by checking the next byte without committing to a
/// `let` keyword parse).
///
/// **O(N) on repeat.** Each `lookAhead` call re-parses `p` from
/// the cursor. There's no memoization. If you need to peek
/// multiple times at the same point, hoist the parse into a
/// `chain`.
///
/// Type inferred from `p`: `lookAhead(digit())` returns
/// `Parser(u21)` — same `T` as the inner parser.
///
/// Example:
/// ```zig
/// const peek_digit = comptime lookAhead(digit());
/// // peek_digit.run("3xy", a) → ok = .{ .value = '3', .index = 0 }
/// // peek_digit.run("xy",  a) → err carrying digit's syntactic shape
/// ```
pub fn lookAhead(comptime p: anytype) core.Parser(@TypeOf(p).Output) {
    return p.lookAhead();
}
