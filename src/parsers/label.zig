const core = @import("core");

/// Wrap `p` so its failures carry `name` as the `parser` identity,
/// **replacing** the inner parser's name. The other fields (`message`,
/// `expected`, `actual`, `context`, etc.) pass through unchanged.
///
/// The wrap-style complement of `inContext` (which preserves the
/// inner identity and adds context). Reach for `label` only when the
/// inner parser's identity would be noise to the consumer — for
/// example, naming a multi-step keyword sequence after the keyword
/// rather than after the last `str` it tried to match.
///
/// Example:
/// ```zig
/// const kw_then = comptime label([]const u8, "kw", str("then"));
/// // kw_then.run("x", a) → err.parser == "kw", err.expected == "then"
/// ```
pub fn label(
    comptime T: type,
    comptime name: []const u8,
    comptime p: core.Parser(T),
) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            if (r == .ok) return r;
            var replaced = r.err;
            replaced.parser = name;
            return .{ .err = replaced };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
