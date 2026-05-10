const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiLower(cp: u21) bool {
    return cp >= 'a' and cp <= 'z';
}

/// Match a single ASCII lowercase letter (`[a-z]`). Returns the
/// matched codepoint as `u21`. ASCII-only.
///
/// Example:
/// ```zig
/// const l = comptime lower();
/// // l.run("foo", a) → ok = .{ .value = 'f', .index = 1 }
/// // l.run("Foo", a) → err
/// ```
pub fn lower() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiLower, "lower");
}
