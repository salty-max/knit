const core = @import("core");

/// Try each `parsers` alternative in order, returning the first
/// success. If every alternative fails, return the **furthest-progress**
/// error (the inner error with the highest `index`); ties are broken
/// by earliest position in the list.
///
/// **Full backtrack between alternatives.** parsil has no
/// `try` / `cut` / commit semantics: the cursor is restored to the
/// pre-`choice` position before each next attempt, even if a prior
/// alternative consumed input before failing. To prevent this (e.g.
/// commit after a unique prefix), express the prefix outside the
/// `choice` and call `choice` only at the divergence point.
///
/// Pass-through on first success: if the matching parser advances
/// the cursor, that advance is preserved — `choice` does NOT undo a
/// successful match.
///
/// **Allocator note.** Failed alternatives may emit `ParseError`s
/// whose `actual` (and `context`, future) carry allocations made
/// via `state.allocator`. `choice` discards every err but the
/// furthest, so those allocations linger past the call. Use the
/// canonical arena-per-parse pattern (`runArena` or feed an
/// `ArenaAllocator`) so they're freed in bulk on `.deinit()`.
///
/// Compile-time error if `parsers.len == 0` — no alternatives is
/// always a programming error, never an intended runtime case.
///
/// Example:
/// ```zig
/// const sign = comptime choice(u21, &.{ char('+'), char('-') });
/// // sign.run("+5", alloc) → ok = .{ .value = '+', .index = 1 }
/// // sign.run("x",  alloc) → err whose .index points at the
/// //                          furthest position any alternative
/// //                          reached (here, 0 — both alts saw 'x')
/// ```
pub fn choice(comptime T: type, comptime parsers: []const core.Parser(T)) core.Parser(T) {
    if (parsers.len == 0) @compileError("choice: parsers slice must contain at least one alternative");
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const start = state.index;
            const start_bit_offset = state.bit_offset;
            const start_recovered_len: usize = if (state.recovered_errs) |list| list.items.len else 0;
            var furthest: ?core.ParseError = null;
            inline for (parsers) |p| {
                state.index = start;
                state.bit_offset = start_bit_offset;
                if (state.recovered_errs) |list| list.shrinkRetainingCapacity(start_recovered_len);
                const r = p.parseFn(state);
                switch (r) {
                    .ok => return r,
                    .err => |e| {
                        if (furthest == null or e.index > furthest.?.index) {
                            furthest = e;
                        }
                    },
                }
            }
            return .{ .err = furthest.? };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
