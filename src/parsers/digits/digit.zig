const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiDigit(cp: u21) bool {
    return cp >= '0' and cp <= '9';
}

/// Match a single ASCII decimal digit (`'0'..'9'`). Returns the
/// matched codepoint as `u21` (always in the ASCII range, but kept
/// uniform with the rest of the char family). Cursor advances by 1
/// byte.
///
/// Failure modes:
/// - Empty input: `kind = .incomplete` (carried over from
///   `satisfy`'s decode-EOF path).
/// - Non-digit at cursor: `kind = .syntactic`.
///
/// Example:
/// ```zig
/// const d = comptime digit();
/// // d.run("3 sheep", alloc) → ok = .{ .value = '3', .index = 1 }
/// // d.run("x", alloc)       → err with parser = "digit"
/// ```
pub fn digit() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiDigit, "digit");
}
