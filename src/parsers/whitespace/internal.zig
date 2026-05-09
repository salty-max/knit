const core = @import("core");

/// True iff `b` is one of the four ASCII whitespace bytes parsil-zig
/// recognises: space, tab, line feed, carriage return.
///
/// Vertical tab (`\v`) and form feed (`\f`) are deliberately
/// excluded — they're vanishingly rare in modern source and
/// excluding them keeps the matcher predictable.
pub fn isWhitespaceByte(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\n' or b == '\r';
}

/// Advance `state.index` past every contiguous whitespace byte at
/// the cursor. Always succeeds — leaves the cursor unchanged when
/// the first byte isn't whitespace or the input is exhausted.
pub fn scanWhitespace(state: *core.ParseState) void {
    while (state.index < state.input.len and isWhitespaceByte(state.input[state.index])) {
        state.advance(1);
    }
}
