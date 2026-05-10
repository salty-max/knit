const std = @import("std");
const core = @import("core");

/// Right-associative fold over a sequence `operand (op operand)*`.
/// Same shape as `chainl1` but folds from the right.
///
/// `op` is a parser producing `*const fn(T, T) T` — see
/// `chainl1` for the picker pattern.
///
/// Result: `a -> b -> c -> d` becomes `a -> (b -> (c -> d))`.
///
/// **Implementation note.** Unlike `chainl1`'s constant-stack
/// left-fold, `chainr1` must collect every `(op, operand)` pair
/// before folding from the right. Two `ArrayList`s allocate via
/// `state.allocator` (pairs of fn-pointers + values), discarded
/// before return. Use `runArena` for bulk cleanup.
///
/// Failure shapes match `chainl1`'s:
/// - First `operand` fails → propagates
/// - `op` fails after some operands → return what we have
/// - `op` succeeds but follow-up `operand` fails → propagate
///
/// Example (`a - b - c` parses to `a - (b - c)`):
/// ```zig
/// const Sub = struct { fn sub(a: i64, b: i64) i64 { return a - b; } };
/// const minus_op = comptime char('-')
///     .map(*const fn(i64, i64) i64, struct {
///         fn pick(_: u21) *const fn(i64, i64) i64 { return &Sub.sub; }
///     }.pick);
/// const expr = comptime chainr1(i64, intLit(), minus_op);
/// // expr.run("1-2-3", a) → ok = .{ .value = 2, .index = 5 } (right-assoc: 1-(2-3) = 2)
/// ```
pub fn chainr1(
    comptime T: type,
    comptime operand: core.Parser(T),
    comptime op: core.Parser(*const fn (T, T) T),
) core.Parser(T) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            const r0 = operand.parseFn(state);
            if (r0 == .err) return .{ .err = r0.err };

            // No `errdefer` — ParseResult is a union; explicit cleanup on err.
            var operands: std.ArrayList(T) = .empty;
            var ops: std.ArrayList(*const fn (T, T) T) = .empty;
            // First operand goes into the list so the fold sees a uniform
            // [a0, a1, …, an] sequence alongside [op0, op1, …, op(n-1)].
            operands.append(state.allocator, r0.ok.value) catch {
                return .{ .err = core.parseError("chainr1", state.index, "out of memory while collecting", .{
                    .kind = .internal,
                }) };
            };

            while (true) {
                const before_op = state.index;
                const ro = op.parseFn(state);
                if (ro == .err) {
                    state.index = before_op;
                    break;
                }
                const r1 = operand.parseFn(state);
                if (r1 == .err) {
                    operands.deinit(state.allocator);
                    ops.deinit(state.allocator);
                    return .{ .err = r1.err };
                }
                ops.append(state.allocator, ro.ok.value) catch {
                    operands.deinit(state.allocator);
                    ops.deinit(state.allocator);
                    return .{ .err = core.parseError("chainr1", state.index, "out of memory while collecting", .{
                        .kind = .internal,
                    }) };
                };
                operands.append(state.allocator, r1.ok.value) catch {
                    operands.deinit(state.allocator);
                    ops.deinit(state.allocator);
                    return .{ .err = core.parseError("chainr1", state.index, "out of memory while collecting", .{
                        .kind = .internal,
                    }) };
                };
                if (state.index == before_op) break;
            }

            // Fold from the right: acc starts as last operand, then each
            // op_i is applied as op_i(operand_i, acc).
            var acc: T = operands.items[operands.items.len - 1];
            var i: usize = ops.items.len;
            while (i > 0) {
                i -= 1;
                acc = ops.items[i](operands.items[i], acc);
            }

            operands.deinit(state.allocator);
            ops.deinit(state.allocator);
            return core.ok(acc, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
