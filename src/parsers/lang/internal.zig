const lexeme_internal = @import("../lexeme/internal.zig");

/// True iff `b` is a valid identifier-START byte under the
/// default lexer profile: ASCII letter or underscore. Digits are
/// NOT valid starts (`9foo` is a number, not an identifier).
pub fn isIdentStart(b: u8) bool {
    return (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z') or b == '_';
}

/// True iff `b` is a valid identifier-CONTINUATION byte: letter,
/// digit, or underscore. Re-exported from `lexeme/internal.zig`
/// so the lang parsers can reach the same predicate that
/// `keyword` uses for boundary checks — keeps the two families
/// aligned on the identifier definition.
pub const isIdentContinuation = lexeme_internal.isIdentContinuation;

/// True iff `b` is a digit valid in the given numeric base
/// (2, 8, 10, or 16). Hex digits accept both upper and lower case.
pub fn isDigitInBase(b: u8, base: u8) bool {
    return switch (base) {
        2 => b == '0' or b == '1',
        8 => b >= '0' and b <= '7',
        10 => b >= '0' and b <= '9',
        16 => (b >= '0' and b <= '9') or
            (b >= 'a' and b <= 'f') or
            (b >= 'A' and b <= 'F'),
        // allow-strict: callers only ever pass 2/8/10/16 (the four bases
        // intLit recognises). Any other value is a programming error
        // caught in dev — invariant maintained at every call site.
        else => unreachable,
    };
}
