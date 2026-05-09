const core = @import("core");
const char_mod = @import("char.zig");

/// Match a single UTF-8 codepoint that appears in `set`.
///
/// Example:
/// ```zig
/// const vowel = comptime oneOf(&.{ 'a', 'e', 'i', 'o', 'u' });
/// // vowel.run("apple", alloc) → ok = .{ .value = 'a', .index = 1 }
/// // vowel.run("xyz", alloc) → err with parser = "oneOf"
/// ```
pub fn oneOf(comptime set: []const u21) core.Parser(u21) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| {
                const r = char_mod.decodeErrorToParseError(err, state.index);
                var e = r.err;
                e.parser = "oneOf";
                return .{ .err = e };
            };
            for (set) |c| {
                if (decoded.cp == c) {
                    state.advance(decoded.width);
                    return core.ok(decoded.cp, state.index);
                }
            }
            return .{ .err = core.parseError("oneOf", state.index, "codepoint not in set", .{
                .kind = .syntactic,
            }) };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
