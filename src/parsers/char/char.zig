const core = @import("core");

/// Match a specific UTF-8 codepoint at the cursor. Advances by the
/// codepoint's byte width on success.
///
/// Example:
/// ```zig
/// const a = comptime char('a');
/// // a.run("apple", alloc) → ok = .{ .value = 'a', .index = 1 }
///
/// const fr = comptime char('é');
/// // fr.run("été", alloc) → ok = .{ .value = 'é', .index = 2 } (2-byte)
/// ```
pub fn char(comptime c: u21) core.Parser(u21) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| return decodeErrorToParseError(err, state.index);
            if (decoded.cp != c) {
                return .{ .err = core.parseError("char", state.index, "unexpected codepoint", .{
                    .kind = .syntactic,
                }) };
            }
            state.advance(decoded.width);
            return core.ok(decoded.cp, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}

/// Translate a `Utf8DecodeError` into a `ParseError` with the right
/// `kind` and message. Shared by all char-family parsers.
pub fn decodeErrorToParseError(err: core.Utf8DecodeError, index: usize) core.ParseResult(u21) {
    return switch (err) {
        error.UnexpectedEof => .{ .err = core.parseError("char", index, "unexpected end of input", .{
            .kind = .incomplete,
        }) },
        error.Utf8Invalid => .{ .err = core.parseError("char", index, "invalid UTF-8 sequence", .{
            .kind = .lexical,
        }) },
        error.Utf8Truncated => .{ .err = core.parseError("char", index, "incomplete UTF-8 sequence", .{
            .kind = .incomplete,
        }) },
    };
}
