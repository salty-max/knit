const core = @import("core");
const char_mod = @import("char.zig");

/// Match a single UTF-8 codepoint that does NOT appear in `set`.
///
/// Example:
/// ```zig
/// const not_quote = comptime noneOf(&.{ '"', '\'', '\\' });
/// // not_quote.run("abc", alloc) → ok = .{ .value = 'a', .index = 1 }
/// // not_quote.run("\"hi", alloc) → err with parser = "noneOf"
/// ```
pub fn noneOf(comptime set: []const u21) core.Parser(u21) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| {
                const r = char_mod.decodeErrorToParseError(err, state.index);
                var e = r.err;
                e.parser = "noneOf";
                return .{ .err = e };
            };
            for (set) |c| {
                if (decoded.cp == c) {
                    return .{ .err = core.parseError("noneOf", state.index, "codepoint in forbidden set", .{
                        .kind = .syntactic,
                    }) };
                }
            }
            state.advance(decoded.width);
            return core.ok(decoded.cp, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
