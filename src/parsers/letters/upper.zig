const core = @import("core");
const satisfy_mod = @import("../char/satisfy.zig");

fn isAsciiUpper(cp: u21) bool {
    return cp >= 'A' and cp <= 'Z';
}

/// Match a single ASCII uppercase letter (`[A-Z]`). Returns the
/// matched codepoint as `u21`. ASCII-only.
///
/// Example:
/// ```zig
/// const u = comptime upper();
/// // u.run("Foo", a) → ok = .{ .value = 'F', .index = 1 }
/// // u.run("foo", a) → err
/// ```
pub fn upper() core.Parser(u21) {
    return satisfy_mod.satisfy(isAsciiUpper, "upper");
}
