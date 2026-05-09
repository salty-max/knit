const core = @import("core");

/// Error recovery / synchronization on a tuple of anchors.
///
/// Run `p`. On success: return `ok(Some(value))`. On failure:
/// scan forward from where `p` left off, trying every anchor
/// at each position; the first anchor to succeed wins, and we
/// return `ok(null)` with the cursor at the recovery point —
/// the anchor itself is NOT consumed (lookahead semantics) so
/// the caller can chain its own consumption. If no anchor
/// matches before EOF (nor at EOF), `p`'s original `ParseError`
/// propagates.
///
/// `anchors` is a comptime tuple — each anchor can be any
/// `Parser(T)` regardless of `T`, since only success/failure
/// matters for synchronization. Mixing `char(';')`, `endOfInput()`,
/// `whitespace1()`, etc. in the same tuple Just Works.
///
/// Used by error-recovery patterns in language grammars: the
/// caller can keep parsing successive constructs even after one
/// fails.
///
/// **Compile-time error if `anchors` has zero entries** —
/// recovery with nowhere to recover to is always a programming
/// error.
///
/// **Allocator note.** Failed anchor attempts may allocate
/// `actual` slices that are discarded by the scan; use the
/// canonical arena-per-parse pattern.
///
/// **Perf.** O(N * A) anchor attempts in the worst case (input
/// length N times anchor-set size A) for a recovery walk.
///
/// Example:
/// ```zig
/// const stmt = comptime str("let x");
/// const recovered = comptime recoverAt(stmt, .{ char(';'), endOfInput() });
/// // recovered.run("let x;rest", a) → ok = .{ .value = "let x", .index = 5 }
/// // recovered.run("BAD;rest",  a) → ok = .{ .value = null,    .index = 3 }
/// // recovered.run("BADbad",    a) → err carrying p's original failure
/// ```
pub fn recoverAt(comptime p: anytype, comptime anchors: anytype) core.Parser(?@TypeOf(p).Output) {
    const anchors_ti = @typeInfo(@TypeOf(anchors));
    if (anchors_ti.@"struct".fields.len == 0) @compileError("recoverAt: anchors tuple must contain at least one parser");
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(?T) {
            const r = p.parseFn(state);
            if (r == .ok) {
                // @as: lift T into ?T so core.ok infers Parser(?T) for the success arm.
                return core.ok(@as(?T, r.ok.value), state.index);
            }
            const original_err = r.err;
            // Scan from where p left off, trying anchors at each position.
            // Loop checks anchors at the current cursor first, then advances —
            // so EOF position is also tried (e.g. endOfInput as anchor).
            while (true) {
                inline for (anchors) |anchor| {
                    const saved = state.index;
                    const ar = anchor.parseFn(state);
                    state.index = saved;
                    if (ar == .ok) {
                        // @as: lift null literal into ?T for the recovery branch's type.
                        return core.ok(@as(?T, null), state.index);
                    }
                }
                if (state.index >= state.input.len) break;
                state.advance(1);
            }
            return .{ .err = original_err };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
