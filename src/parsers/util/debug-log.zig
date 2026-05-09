const std = @import("std");
const core = @import("core");

/// Run `p`, print a one-line trace of the result to stderr
/// prefixed with `label`, then return `p`'s result unchanged.
///
/// Trace shape:
/// - `[label] at index N -> ok at K` on success (N = pre-cursor, K = post)
/// - `[label] at index N -> err: <message>` on failure
///
/// Drop in around any sub-parser to see what's happening at a
/// specific point in a grammar, without rewriting the structure.
///
/// **Output channel.** Writes to `std.debug.print`, which goes
/// to stderr unbuffered. The strict-lint normally bans
/// `std.debug.print` in `src/`; this file is the only exempt
/// path (per the lint script's per-file exception). Consumers
/// leave `debugLog` in tests / dev builds and remove (or
/// `comptime` off) before shipping.
///
/// **No memory cost.** The parser itself doesn't allocate; the
/// `std.debug.print` machinery uses a per-thread buffer in stdlib.
///
/// Example:
/// ```zig
/// const p = comptime debugLog(digits(), "num");
/// // p.run("42x", a) → ok = .{ .value = "42", .index = 2 }
/// //                   stderr: [num] at index 0 -> ok at 2
/// ```
pub fn debugLog(comptime p: anytype, comptime label: []const u8) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const before = state.index;
            const r = p.parseFn(state);
            switch (r) {
                .ok => |ok| std.debug.print("[{s}] at index {d} -> ok at {d}\n", .{ label, before, ok.index }),
                .err => |e| std.debug.print("[{s}] at index {d} -> err: {s}\n", .{ label, before, e.message }),
            }
            return r;
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
