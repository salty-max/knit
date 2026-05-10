const std = @import("std");
const core = @import("core");
const internal = @import("internal.zig");

/// Match the exact string `s` followed by a non-identifier byte
/// (or end-of-input), then consume trailing whitespace. Returns
/// the borrowed `s` slice. The identifier-boundary check
/// distinguishes keyword tokens from prefix matches:
/// `keyword("if")` matches `"if "`, `"if;"`, `"if"` (EOF), but
/// rejects `"ifx"` and `"if_x"`.
///
/// Compile-time error if `s` is empty (an empty keyword has no
/// well-defined boundary semantics).
///
/// Identifier-continuation chars are `[a-zA-Z0-9_]` per the
/// default lexer profile (same as the `identifier` parser).
/// For Unicode-letter identifiers, the consumer should build
/// their own check on top of `str(...)` and a richer `satisfy`
/// predicate.
///
/// **UTF-8 caveat.** The boundary check operates on bytes, not
/// codepoints. A multi-byte UTF-8 codepoint like `'é'`
/// (`0xC3 0xA9`) has a leading byte ≥ `0xC0` which is NOT
/// matched by the ASCII-only `isIdentContinuation` — so
/// `keyword("if").run("if é", ...)` succeeds even though `'é'`
/// is a valid identifier character in many real-world languages.
/// If your grammar needs Unicode-aware boundary checks, build
/// the keyword + boundary check manually with `satisfy`.
///
/// **Perf.** Single byte-by-byte literal compare + one boundary
/// byte check + the inlined whitespace skip. Zero allocation —
/// `actual` (on err) borrows from `state.input` like the
/// char-family parsers post-#98.
///
/// Three failure shapes:
/// - **Not enough input** for `s` → `.incomplete`
/// - **Literal mismatch** → `.syntactic`
/// - **Identifier boundary** (next byte is `[a-zA-Z0-9_]`) → `.syntactic`
///
/// Example:
/// ```zig
/// const if_kw = comptime keyword("if");
/// // if_kw.run("if foo", a) → ok = .{ .value = "if", .index = 3 }
/// // if_kw.run("if",     a) → ok = .{ .value = "if", .index = 2 }
/// // if_kw.run("ifx",    a) → err (identifier boundary violated)
/// // if_kw.run("else",   a) → err (literal mismatch)
/// ```
pub fn keyword(comptime s: []const u8) core.Parser([]const u8) {
    if (s.len == 0) @compileError("keyword: literal must not be empty");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            const start = state.index;
            // Boundary 1: enough input to compare against `s`?
            if (state.index + s.len > state.input.len) {
                return .{ .err = core.parseError("keyword", state.index, "unexpected end of input", .{
                    .expected = s,
                    .kind = .incomplete,
                }) };
            }
            // Boundary 2: literal match?
            const window = state.input[state.index .. state.index + s.len];
            if (!std.mem.eql(u8, window, s)) {
                return .{ .err = core.parseError("keyword", state.index, "expected keyword", .{
                    .expected = s,
                    .actual = window,
                    .kind = .syntactic,
                }) };
            }
            // Boundary 3: next byte (if any) must NOT be an identifier-continuation char.
            const next_idx = state.index + s.len;
            if (next_idx < state.input.len and internal.isIdentContinuation(state.input[next_idx])) {
                return .{ .err = core.parseError("keyword", state.index, "keyword followed by identifier character", .{
                    .expected = s,
                    .actual = state.input[state.index .. next_idx + 1],
                    .kind = .syntactic,
                }) };
            }
            state.advance(s.len);
            internal.skipWhitespace(state);
            return core.ok(state.input[start .. start + s.len], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
