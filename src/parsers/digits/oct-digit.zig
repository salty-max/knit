const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiOctDigit(cp: u21) bool {
    return cp >= '0' and cp <= '7';
}

/// Match a single ASCII octal digit (`'0'..'7'`). Returns the
/// matched codepoint as `u21`.
///
/// Failure shapes inherited from `satisfy`: empty input →
/// `.incomplete`, non-octal-digit → `.syntactic`.
///
/// Example:
/// ```zig
/// const o = comptime octDigit();
/// // o.run("7xy", a) → ok = .{ .value = '7', .index = 1 }
/// // o.run("8",   a) → err (8 is not octal)
/// ```
pub fn octDigit() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiOctDigit, "octDigit");
}
