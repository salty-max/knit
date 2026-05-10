const core = @import("core");

/// Run `p`; on failure, replace the error's `parser` (identity)
/// field with `name`. On success, return unchanged.
///
/// Use to give a sub-parser a domain-specific identity in
/// diagnostics: `tag(intLit(), "port-number")` makes errors
/// show `parser = "port-number"` instead of the generic
/// `"intLit"`. Pair with `expect(p, msg)` to also override the
/// error message.
///
/// Example:
/// ```zig
/// const port = comptime tag(intLit(), "port-number");
/// // port.run("xyz", a) → err with .parser = "port-number"
/// //                      (.message, .index, etc. unchanged)
/// ```
pub fn tag(comptime p: anytype, comptime name: []const u8) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            if (r == .err) {
                var new_err = r.err;
                new_err.parser = name;
                return .{ .err = new_err };
            }
            return r;
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
