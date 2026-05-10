const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiHexDigit(cp: u21) bool {
    return (cp >= '0' and cp <= '9') or
        (cp >= 'a' and cp <= 'f') or
        (cp >= 'A' and cp <= 'F');
}

/// Match a single ASCII hexadecimal digit (`'0'..'9'`, `'a'..'f'`,
/// or `'A'..'F'`). Returns the matched codepoint as `u21`.
///
/// ASCII-only by design (consistent with the rest of the digit
/// family). Failure shapes inherited from `satisfy`: empty input
/// → `.incomplete`, non-hex-digit → `.syntactic`.
///
/// Example:
/// ```zig
/// const h = comptime hexDigit();
/// // h.run("Fxy", a) → ok = .{ .value = 'F', .index = 1 }
/// // h.run("9",   a) → ok = .{ .value = '9', .index = 1 }
/// // h.run("g",   a) → err with parser = "hexDigit"
/// ```
pub fn hexDigit() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiHexDigit, "hexDigit");
}
