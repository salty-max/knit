const core = @import("core");

/// Run `p`; on failure, replace the error's `parser` (identity)
/// field with `name`. On success, return unchanged.
///
/// Same effect as the existing `label(T, name, p)` but with
/// inferred `T` and the canonical `(p, name)` argument order
/// — matches the harmonized signature shape used by the rest
/// of the inferred-type API. `label` and `tag` will eventually
/// converge (one will be removed in a follow-up); for now both
/// exist.
///
/// Use to give a sub-parser a domain-specific identity in
/// diagnostics: `tag(intLit(), "port-number")` makes errors
/// show `parser = "port-number"` instead of the generic
/// `"intLit"`.
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
