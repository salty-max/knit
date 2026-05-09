const std = @import("std");
const core = @import("core");

/// Outcome of `collectSepBy`: the value list (separator values are
/// discarded), plus the err from the failed attempt that ended the
/// loop (if any). `last_err` lets the *one variants emit the
/// precise diagnostic when zero values matched.
pub fn CollectResult(comptime T: type) type {
    return struct {
        values: []T,
        last_err: ?core.ParseError,
    };
}

/// Run `p` then `(sep, p)*` until either side fails. Collected
/// values come from `p`; separator values are discarded.
///
/// `allow_trailing_sep` controls cursor behavior on the final
/// `(sep, p_failure)` iteration:
/// - `false` (sepBy / sepByOne): roll back so the trailing
///   separator is NOT consumed — cursor lands on the sep position.
/// - `true` (sepEndBy / sepEndByOne): keep the cursor after the
///   trailing separator — the dangling sep IS consumed.
///
/// Same no-progress guard as `many`: if a full `(sep, p)` pair
/// succeeds without advancing the cursor, the loop breaks after
/// recording the value to avoid spinning.
///
/// Allocator OOM propagates as a Zig error; the caller wraps into
/// a `ParseError` with the appropriate parser identity.
pub fn collectSepBy(
    comptime T: type,
    comptime S: type,
    comptime sep: core.Parser(S),
    comptime p: core.Parser(T),
    state: *core.ParseState,
    comptime allow_trailing_sep: bool,
) std.mem.Allocator.Error!CollectResult(T) {
    var list: std.ArrayList(T) = .empty;
    errdefer list.deinit(state.allocator);

    var last_err: ?core.ParseError = null;

    const first_pos = state.index;
    {
        const r = p.parseFn(state);
        if (r == .err) {
            state.index = first_pos;
            last_err = r.err;
            return .{ .values = try list.toOwnedSlice(state.allocator), .last_err = last_err };
        }
        try list.append(state.allocator, r.ok.value);
    }

    while (true) {
        const before_sep = state.index;
        const rs = sep.parseFn(state);
        if (rs == .err) {
            state.index = before_sep;
            last_err = rs.err;
            break;
        }
        const after_sep = state.index;
        const rp = p.parseFn(state);
        if (rp == .err) {
            state.index = if (allow_trailing_sep) after_sep else before_sep;
            last_err = rp.err;
            break;
        }
        try list.append(state.allocator, rp.ok.value);
        if (state.index == before_sep) break;
    }
    return .{ .values = try list.toOwnedSlice(state.allocator), .last_err = last_err };
}
