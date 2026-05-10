const core = @import("core");

/// Match any single byte at the cursor that does NOT start a
/// successful parse of `p`. Returns the matched byte (`u8`),
/// advancing the cursor by one byte on success.
///
/// `p` is run in a lookAhead-style savepoint: the cursor is
/// always restored after `p`'s attempt, regardless of outcome.
/// If `p` succeeded → fail (we're at a forbidden position);
/// if `p` failed → consume one byte and return it.
///
/// **Byte-level**, not codepoint-aware. For codepoint-level
/// negation, build via `satisfy(...)`.
///
/// Failure shapes:
/// - EOF at cursor → `.incomplete`
/// - `p` succeeds at cursor → `.syntactic` (forbidden position)
///
/// Pass-through on the parser side — inherits allocator behavior
/// from `p`; `anyCharExcept` itself adds no allocation.
///
/// Example:
/// ```zig
/// const not_semicolon = comptime anyCharExcept(char(';'));
/// // not_semicolon.run("a;", a) → ok = .{ .value = 'a', .index = 1 }
/// // not_semicolon.run(";a", a) → err with kind = .syntactic
/// ```
pub fn anyCharExcept(comptime p: anytype) core.Parser(u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("anyCharExcept", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const saved = state.index;
            const saved_bit_offset = state.bit_offset;
            const saved_recovered_len: usize = if (state.recovered_errs) |list| list.items.len else 0;
            const r = p.parseFn(state);
            state.index = saved;
            state.bit_offset = saved_bit_offset;
            if (state.recovered_errs) |list| list.shrinkRetainingCapacity(saved_recovered_len);
            if (r == .ok) {
                return .{ .err = core.parseError("anyCharExcept", state.index, "forbidden parser matched at cursor", .{
                    .kind = .syntactic,
                }) };
            }
            const b = state.input[state.index];
            state.advance(1);
            return core.ok(b, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
