const std = @import("std");
const core = @import("core");
const internal = @import("internal.zig");

/// Match an unsigned decimal float literal: integer part,
/// optional fractional part, optional exponent. Returns `f64`.
///
/// The literal itself is **unsigned** — use `signed(floatLit())`
/// to admit a leading `-` or `+` sign. (Note: this deviates from
/// the original issue spec which had the sign internal — keeping
/// it in `signed` lets `intLit` and `floatLit` share the
/// negation wrapper without each re-implementing it.)
///
/// Recognised shapes:
/// - `3` (integer part only — but at least one fractional or
///   exponent component must be present, otherwise it's an
///   integer not a float)
/// - `3.14` (fractional)
/// - `1e10` (exponent)
/// - `2.5e-3` (both)
///
/// **Identifier boundary** like `intLit`: a float followed by
/// `[a-zA-Z_]` is rejected (`3.14foo` fails).
///
/// Failure shapes:
/// - Empty input → `.incomplete`
/// - No integer digits → `.syntactic`
/// - No fractional/exponent component (it's an integer, not a
///   float) → `.syntactic`
/// - Out-of-range or malformed → `.syntactic`
/// - Identifier byte after the literal → `.syntactic`
///
/// Zero allocation.
///
/// Example:
/// ```zig
/// const x = comptime floatLit();
/// // x.run("3.14",   a) → ok = .{ .value = 3.14, .index = 4 }
/// // x.run("1e10",   a) → ok = .{ .value = 1e10, .index = 4 }
/// // x.run("2.5e-3", a) → ok = .{ .value = 0.0025, .index = 6 }
/// // x.run("42",     a) → err (no fractional/exponent — it's intLit's shape)
/// ```
pub fn floatLit() core.Parser(f64) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(f64) {
            const start = state.index;
            if (start >= state.input.len) {
                return .{ .err = core.parseError("floatLit", start, "unexpected end of input", .{
                    .expected = "float literal",
                    .kind = .incomplete,
                }) };
            }
            // Integer part — at least one decimal digit.
            var i = start;
            while (i < state.input.len and internal.isDigitInBase(state.input[i], 10)) : (i += 1) {}
            if (i == start) {
                return .{ .err = core.parseError("floatLit", start, "expected leading digit", .{
                    .expected = "digit",
                    .kind = .syntactic,
                }) };
            }
            // Optional fractional part.
            var has_fraction = false;
            if (i < state.input.len and state.input[i] == '.') {
                const dot_pos = i;
                i += 1;
                const frac_start = i;
                while (i < state.input.len and internal.isDigitInBase(state.input[i], 10)) : (i += 1) {}
                if (i == frac_start) {
                    // A '.' followed by no digits — treat it as not-our-business.
                    // Restore i to before the dot so the next parser sees it.
                    i = dot_pos;
                } else {
                    has_fraction = true;
                }
            }
            // Optional exponent: e/E [+/-]? digits+
            var has_exponent = false;
            if (i < state.input.len and (state.input[i] == 'e' or state.input[i] == 'E')) {
                const e_pos = i;
                i += 1;
                if (i < state.input.len and (state.input[i] == '+' or state.input[i] == '-')) {
                    i += 1;
                }
                const exp_start = i;
                while (i < state.input.len and internal.isDigitInBase(state.input[i], 10)) : (i += 1) {}
                if (i == exp_start) {
                    // 'e' without exponent digits — back out.
                    i = e_pos;
                } else {
                    has_exponent = true;
                }
            }
            // A bare integer (no fraction, no exponent) isn't a float — defer to intLit.
            if (!has_fraction and !has_exponent) {
                return .{ .err = core.parseError("floatLit", start, "expected fractional or exponent component", .{
                    .expected = "'.' or 'e'",
                    .kind = .syntactic,
                }) };
            }
            // Identifier boundary.
            if (i < state.input.len and internal.isIdentStart(state.input[i])) {
                return .{ .err = core.parseError("floatLit", start, "float literal followed by identifier character", .{
                    .actual = state.input[start .. i + 1],
                    .kind = .syntactic,
                }) };
            }
            const literal = state.input[start..i];
            const value = std.fmt.parseFloat(f64, literal) catch {
                return .{ .err = core.parseError("floatLit", start, "float out of range or malformed", .{
                    .actual = literal,
                    .kind = .syntactic,
                }) };
            };
            state.index = i;
            return core.ok(value, i);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
