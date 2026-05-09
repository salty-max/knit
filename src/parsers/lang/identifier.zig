const core = @import("core");
const internal = @import("internal.zig");

/// Match an identifier under the default lexer profile: a leading
/// ASCII letter or underscore, followed by zero or more letters,
/// digits, or underscores.
///
/// Returns the identifier as a slice borrowed from `state.input`
/// — zero allocation, lifetime is the caller's input.
///
/// Two failure shapes:
/// - **Empty input** → `.incomplete`
/// - **Bad start byte** (digit or punctuation) → `.syntactic`
///
/// **Identifier definition** matches `keyword`'s boundary check
/// (both share `isIdentContinuation`), so a `keyword(...)` and
/// the same string parsed via `identifier()` cannot diverge on
/// what counts as "the rest of the identifier".
///
/// Example:
/// ```zig
/// const ident = comptime identifier();
/// // ident.run("foo_1 bar", a) → ok = .{ .value = "foo_1", .index = 5 }
/// // ident.run("_priv",     a) → ok = .{ .value = "_priv", .index = 5 }
/// // ident.run("9digits",   a) → err with kind = .syntactic
/// ```
pub fn identifier() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("identifier", state.index, "unexpected end of input", .{
                    .expected = "identifier",
                    .kind = .incomplete,
                }) };
            }
            const start = state.index;
            const first = state.input[start];
            if (!internal.isIdentStart(first)) {
                return .{ .err = core.parseError("identifier", start, "expected identifier start (letter or '_')", .{
                    .expected = "letter or '_'",
                    .actual = state.input[start..][0..1],
                    .kind = .syntactic,
                }) };
            }
            state.advance(1);
            while (state.index < state.input.len and internal.isIdentContinuation(state.input[state.index])) {
                state.advance(1);
            }
            return core.ok(state.input[start..state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
