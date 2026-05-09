const std = @import("std");
const core = @import("core");

/// Outcome of `collectMany`: the values collected by the inner
/// parser plus the err captured on the first failed attempt (if
/// any). `last_err` lets `manyOne` emit the precise diagnostic
/// when no value matched at all.
pub fn CollectResult(comptime T: type) type {
    return struct {
        values: []T,
        last_err: ?core.ParseError,
    };
}

/// Run `p` repeatedly until it fails or stops making progress.
/// Returns the collected values (allocated via `state.allocator`)
/// plus the err from the failed attempt — caller decides whether
/// emptiness is acceptable and shapes the final result.
///
/// The no-progress guard is critical: if `p` succeeds without
/// consuming any input (e.g. `whitespace()`, `succeed(...)`,
/// `lookahead`), looping again would re-run forever. Mirrors the
/// parsil-TS fix from issue #26 there.
///
/// Allocator OOM propagates as a Zig error; the caller wraps it
/// into a `ParseError` with the appropriate parser identity.
pub fn collectMany(
    comptime T: type,
    comptime p: core.Parser(T),
    state: *core.ParseState,
) std.mem.Allocator.Error!CollectResult(T) {
    var list: std.ArrayList(T) = .empty;
    errdefer list.deinit(state.allocator);

    var last_err: ?core.ParseError = null;
    while (true) {
        const before = state.index;
        const r = p.parseFn(state);
        if (r == .err) {
            state.index = before;
            last_err = r.err;
            break;
        }
        try list.append(state.allocator, r.ok.value);
        if (state.index == before) break;
    }
    return .{ .values = try list.toOwnedSlice(state.allocator), .last_err = last_err };
}
