/// True iff `b` is an identifier-continuation byte under the
/// default lexer profile: ASCII letter, digit, or underscore.
/// Shared by `keyword` (boundary check) and the future
/// `identifier` parser (#48). Unicode-letter identifiers can be
/// opted into via a richer custom predicate.
pub fn isIdentContinuation(b: u8) bool {
    return (b >= 'a' and b <= 'z') or
        (b >= 'A' and b <= 'Z') or
        (b >= '0' and b <= '9') or
        b == '_';
}

/// True iff `b` is one of the four ASCII whitespace bytes the
/// `tok` / `keyword` lexeme wrappers consume after the payload:
/// space, tab, line feed, carriage return.
pub fn isLexemeWhitespace(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\n' or b == '\r';
}

/// Advance `state.index` past every contiguous trailing
/// whitespace byte at the cursor. Always succeeds (zero advance
/// is fine). Same semantics as `whitespace()` but inline — keeps
/// the lexeme hot path free of an extra `parseFn` indirection.
pub fn skipWhitespace(state: *@import("core").ParseState) void {
    while (state.index < state.input.len and isLexemeWhitespace(state.input[state.index])) {
        state.advance(1);
    }
}
