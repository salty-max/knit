const core = @import("core");
const internal = @import("internal.zig");

/// Run `p`, then consume trailing ASCII whitespace (space, tab,
/// `\n`, `\r`). Returns `p`'s value with `.Output` preserved —
/// the trailing whitespace is silently absorbed, never surfaces.
///
/// The canonical "make `p` token-aware" wrapper for hand-written
/// lexers: chain `tok(...)` around each token primitive so the
/// next parser starts on the next non-whitespace byte without
/// boilerplate.
///
/// **Perf.** Whitespace skip is inlined (no `parseFn` indirection
/// through `whitespace()`); zero allocation.
///
/// Example:
/// ```zig
/// const num = comptime tok(digits());
/// // num.run("42  next", a) → ok = .{ .value = "42", .index = 4 }
/// // num.run("42",       a) → ok = .{ .value = "42", .index = 2 }
/// // num.run("xyz",      a) → err carrying digits's syntactic shape
/// ```
pub fn tok(comptime p: anytype) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            if (r == .err) return r;
            internal.skipWhitespace(state);
            return core.ok(r.ok.value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
