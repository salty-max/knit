const core = @import("core");

/// Make `p` optional: success wraps the value in `?T`, failure
/// rolls back to the pre-`possibly` cursor and returns `ok` with
/// `null`. **Always succeeds.**
///
/// Type inferred from `p`: `possibly(digits())` returns
/// `Parser(?[]const u8)`. Use Zig's optional unwrapping
/// (`if (val) |v| { ... } else { ... }`) at the call site.
///
/// **Allocator note.** The inner parser's `ParseError` is
/// discarded on failure; if it allocated `actual` (or future
/// `context`) via `state.allocator`, those allocations linger
/// until arena cleanup. Use `runArena` for bulk reclamation.
///
/// Composes cleanly with `sequenceOf` (optional fields) and
/// `many` (collecting `?T`s — though most grammars want
/// `many(possibly(p))` to be flattened via `.map`).
///
/// Example:
/// ```zig
/// const sign = comptime possibly(char('-'));
/// // sign.run("-42", a) → ok = .{ .value = '-',  .index = 1 }
/// // sign.run("42",  a) → ok = .{ .value = null, .index = 0 }
/// ```
pub fn possibly(comptime p: anytype) core.Parser(?@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(?T) {
            const before = state.index;
            const r = p.parseFn(state);
            if (r == .err) {
                state.index = before;
                // @as: coerce the untyped null literal to ?T so core.ok infers Parser(?T).
                return core.ok(@as(?T, null), before);
            }
            // @as: lift the inner T value into ?T so the success arm matches the failure arm's type.
            return core.ok(@as(?T, r.ok.value), state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
