const core = @import("core");
const internal = @import("internal.zig");

/// Match a single UTF-8 codepoint that satisfies the supplied
/// `predicate`. The `name` is used as the `parser` identity in the
/// emitted `ParseError` — keep it short and purpose-naming
/// (`"digit"`, `"vowel"`, `"hex digit"`).
///
/// Example:
/// ```zig
/// const isDigit = struct {
///     fn check(cp: u21) bool { return cp >= '0' and cp <= '9'; }
/// }.check;
/// const digit = comptime satisfy(isDigit, "digit");
/// // digit.run("3 sheep", alloc) → ok = .{ .value = '3', .index = 1 }
/// // digit.run("x", alloc) → err with parser = "digit"
/// ```
pub fn satisfy(comptime predicate: fn (u21) bool, comptime name: []const u8) core.Parser(u21) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| return internal.decodeErrorToParseError(err, state.index, name, null);
            if (!predicate(decoded.cp)) {
                return .{ .err = core.parseError(name, state.index, "predicate did not match", .{
                    .actual = core.encodeCpAlloc(state.allocator, decoded.cp),
                    .kind = .syntactic,
                }) };
            }
            state.advance(decoded.width);
            return core.ok(decoded.cp, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
