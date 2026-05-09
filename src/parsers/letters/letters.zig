const core = @import("core");

fn isLetterByte(b: u8) bool {
    return (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z');
}

/// Match one-or-more contiguous ASCII letters and return the
/// matched byte slice borrowed from the input. The slice's lifetime
/// is the input's — `letters` allocates nothing.
///
/// ASCII-only by design (a-z + A-Z). For Unicode-letter runs, build
/// one out of `satisfy` + a future `many1` combinator.
///
/// Implementation note: ASCII letters are always 1-byte, so the
/// inner loop scans bytes directly without UTF-8 decoding. A
/// non-letter byte (including the leading byte of any multi-byte
/// codepoint and any invalid byte) ends the match cleanly.
///
/// Failure modes:
/// - Empty input at cursor: `kind = .incomplete`.
/// - First byte is not a letter: `kind = .syntactic`, cursor unchanged.
///
/// Example:
/// ```zig
/// const ls = comptime letters();
/// // ls.run("hello123", alloc) → ok = .{ .value = "hello", .index = 5 }
/// // ls.run("123", alloc)      → err with parser = "letters", cursor 0
/// ```
pub fn letters() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index >= state.input.len) {
                return .{ .err = core.parseError("letters", state.index, "unexpected end of input", .{
                    .expected = "a-zA-Z",
                    .kind = .incomplete,
                }) };
            }
            const start = state.index;
            while (state.index < state.input.len) {
                if (!isLetterByte(state.input[state.index])) break;
                state.advance(1);
            }
            if (state.index == start) {
                return .{ .err = core.parseError("letters", state.index, "expected one or more ASCII letters", .{
                    .expected = "a-zA-Z",
                    .kind = .syntactic,
                }) };
            }
            return core.ok(state.input[start..state.index], state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
