const core = @import("core");

/// Run `p`; on failure, replace the error's `message` field with
/// the supplied `msg`. All other fields (`parser`, `index`,
/// `expected`, `actual`, `context`, `severity`, `kind`) pass
/// through unchanged. On success, return unchanged.
///
/// Use to add a domain-specific message at consumer boundaries
/// — `expect(intLit(), "expected port number 0-65535")` keeps
/// the parser identity (`intLit`) and position info but swaps
/// the generic library message for one that means something to
/// the end user.
///
/// Compare with `tag` (replaces `err.parser` instead of
/// `err.message`) and `label` (replaces `err.parser` — same as
/// `tag` but with explicit `T` arg, slated for harmonization).
/// All three are zero-allocation field overwrites.
///
/// Example:
/// ```zig
/// const port = comptime expect(intLit(), "expected port number");
/// // port.run("xyz", a) → err with .message = "expected port number"
/// //                      (.parser = "intLit", .index = 0, etc. unchanged)
/// ```
pub fn expect(comptime p: anytype, comptime msg: []const u8) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            if (r == .err) {
                var new_err = r.err;
                new_err.message = msg;
                return .{ .err = new_err };
            }
            return r;
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
