const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiAlphaNum(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or
        (cp >= 'A' and cp <= 'Z') or
        (cp >= '0' and cp <= '9');
}

/// Match a single ASCII alphanumeric character (`[a-zA-Z0-9]`).
/// Returns the matched codepoint as `u21`. ASCII-only — Unicode
/// alphanumerics require a custom `satisfy` predicate.
///
/// Failure shapes inherited from `satisfy`: empty input →
/// `.incomplete`, non-alphanumeric → `.syntactic`.
///
/// Example:
/// ```zig
/// const c = comptime alphaNum();
/// // c.run("a1", a) → ok = .{ .value = 'a', .index = 1 }
/// // c.run("9",  a) → ok = .{ .value = '9', .index = 1 }
/// // c.run("!",  a) → err
/// ```
pub fn alphaNum() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiAlphaNum, "alphaNum");
}
