const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiLetter(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z');
}

/// Match a single ASCII letter (`'a'..'z'` or `'A'..'Z'`). Returns
/// the matched codepoint as `u21`. Cursor advances by 1 byte.
///
/// ASCII-only by design: Unicode letters (accented, CJK, etc.)
/// require a richer predicate — opt in via `satisfy(myPredicate, "letter")`
/// at the call site.
///
/// Failure modes:
/// - Empty input: `kind = .incomplete`.
/// - Non-letter at cursor: `kind = .syntactic`.
///
/// Example:
/// ```zig
/// const l = comptime letter();
/// // l.run("Apple", alloc) → ok = .{ .value = 'A', .index = 1 }
/// // l.run("3", alloc)     → err with parser = "letter"
/// ```
pub fn letter() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiLetter, "letter");
}
