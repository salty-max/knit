const core = @import("core");

/// Return the byte at the cursor without advancing. Byte-level
/// — does NOT decode UTF-8. For a multi-byte codepoint, returns
/// the leading byte (e.g. `0xC3` for `'é'`); use `anyChar` /
/// `lookAhead(anyChar())` for codepoint-level peeking.
///
/// Distinct from `lookAhead(p)`: `peek` is a primitive that
/// reads one byte directly; `lookAhead` wraps an arbitrary
/// parser and restores the cursor on success.
///
/// **EOF** → err with `parser = "peek"`, `kind = .incomplete`.
///
/// Example:
/// ```zig
/// const p = comptime peek();
/// // p.run("abc", a) → ok = .{ .value = 'a', .index = 0 }
/// // p.run("",    a) → err with parser = "peek", kind = .incomplete
/// ```
pub fn peek() core.Parser(u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("peek", state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            return core.ok(state.input[state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
