const core = @import("core");

/// Sequence: run `p`, hand its value to `fn_chain` to produce
/// the next parser, then run that. Failures from either side
/// propagate. Free-function form of `Parser(T).chain` — same
/// semantics, just spelled positionally for grammars where
/// `chain(P, U, build)` reads more naturally than
/// `P.chain(U, build)`.
///
/// Use when the next parser depends on the previous one's value
/// (length-prefixed encodings, type-tagged choices, etc.). For
/// pure value transformation use `.map`; for fixed sequencing
/// without value dependency use `.then` / `sequenceOf`.
///
/// Type inference: `T` is derived from `p` via `@TypeOf(p).Output`;
/// `U` is given explicitly because Zig can't always infer it from
/// the function type alone (matches the existing `Parser(T).chain`
/// signature shape).
///
/// Example:
/// ```zig
/// // Tag-dispatched: 'd' followed by digits, anything else by letters.
/// const Build = struct {
///     fn dispatch(tag: u21) Parser([]const u8) {
///         return if (tag == 'd') digits() else letters();
///     }
/// };
/// const p = comptime chain(anyChar(), []const u8, Build.dispatch);
/// // p.run("d123!", a) → ok = .{ .value = "123", .index = 4 }
/// // p.run("labc!", a) → ok = .{ .value = "abc", .index = 4 }
/// ```
///
/// Note on length-prefix-style decoding: the inner parser is
/// chosen at runtime, so it can't pass a runtime count to a
/// comptime-`n` combinator like `exactly`. For genuine
/// length-prefix patterns, gate inside `fn_chain` with `many`
/// plus an external length check, or wait for the
/// runtime-bounded `repeatN` (planned).
pub fn chain(comptime p: anytype, comptime U: type, comptime fn_chain: anytype) core.Parser(U) {
    return p.chain(U, fn_chain);
}
