const std = @import("std");
const core = @import("core");

/// Wrap `p` so its failures carry an extra context label, prepended
/// to `err.context` outer-first.
///
/// Outer-first means the OUTERMOST `inContext` label appears at
/// `context[0]`. Reading the slice left-to-right reads as
/// "while parsing OUTER's INNER's …".
///
/// Example:
/// ```zig
/// const expr_in_call = comptime
///     inContext([]const u8, "function call",
///         inContext([]const u8, "argument list", str("hi")));
/// // On failure, err.context == &.{ "function call", "argument list" }
/// ```
///
/// Allocates a new context slice via `state.allocator` each time it
/// fires. The arena pattern (`runArena`) frees them all in bulk.
/// On allocator failure, returns the inner error without enrichment
/// rather than failing the whole parse with a different shape.
pub fn inContext(
    comptime T: type,
    comptime label: []const u8,
    comptime p: core.Parser(T),
) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r = p.parseFn(state);
            if (r == .ok) return r;

            const old_ctx = r.err.context;
            const new_ctx = state.allocator.alloc([]const u8, old_ctx.len + 1) catch {
                return .{ .err = r.err };
            };
            new_ctx[0] = label;
            std.mem.copyForwards([]const u8, new_ctx[1..], old_ctx);

            var enriched = r.err;
            enriched.context = new_ctx;
            return .{ .err = enriched };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
