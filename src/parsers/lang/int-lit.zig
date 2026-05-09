const std = @import("std");
const core = @import("core");
const internal = @import("internal.zig");

/// Match an unsigned integer literal in one of four bases:
/// - **Decimal**: `42`, `1234`
/// - **Hexadecimal** (prefix `0x` or `0X`): `0xDEAD`, `0xff`
/// - **Octal** (prefix `0o` or `0O`): `0o755`
/// - **Binary** (prefix `0b` or `0B`): `0b1010`
///
/// Returns the parsed value as `i64`. The literal itself is
/// **unsigned** — use `signed(intLit())` to admit a leading
/// `-` or `+` sign.
///
/// **Identifier boundary**: an integer immediately followed by a
/// letter, digit-out-of-base, or underscore is rejected. So
/// `0x1g` fails (`g` is not a hex digit AND would form an
/// identifier-suffix). This matches the keyword/identifier
/// boundary convention.
///
/// Failure shapes:
/// - Empty input → `.incomplete`
/// - No valid digits after the prefix → `.syntactic`
/// - Out-of-range or malformed → `.syntactic`
/// - Identifier byte immediately after the digits → `.syntactic`
///
/// Zero allocation; the err's `actual` (when present) borrows
/// from `state.input`.
///
/// Example:
/// ```zig
/// const n = comptime intLit();
/// // n.run("42abc",   a) → err (identifier boundary on 'a')
/// // n.run("42",      a) → ok = .{ .value = 42,    .index = 2 }
/// // n.run("0xff",    a) → ok = .{ .value = 255,   .index = 4 }
/// // n.run("0o755",   a) → ok = .{ .value = 493,   .index = 5 }
/// // n.run("0b1010",  a) → ok = .{ .value = 10,    .index = 6 }
/// ```
pub fn intLit() core.Parser(i64) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(i64) {
            const start = state.index;
            if (start >= state.input.len) {
                return .{ .err = core.parseError("intLit", start, "unexpected end of input", .{
                    .expected = "integer literal",
                    .kind = .incomplete,
                }) };
            }
            // Detect base prefix.
            var base: u8 = 10;
            var body_start: usize = start;
            if (start + 2 <= state.input.len and state.input[start] == '0') {
                const px = state.input[start + 1];
                if (px == 'x' or px == 'X') {
                    base = 16;
                    body_start = start + 2;
                } else if (px == 'o' or px == 'O') {
                    base = 8;
                    body_start = start + 2;
                } else if (px == 'b' or px == 'B') {
                    base = 2;
                    body_start = start + 2;
                }
            }
            // Scan body: digits valid in the chosen base.
            var i = body_start;
            while (i < state.input.len and internal.isDigitInBase(state.input[i], base)) : (i += 1) {}
            if (i == body_start) {
                return .{ .err = core.parseError("intLit", start, "expected integer digits", .{
                    .expected = "digit",
                    .kind = .syntactic,
                }) };
            }
            // Identifier boundary: digit run must not be followed by a letter or underscore.
            if (i < state.input.len) {
                const next = state.input[i];
                if (internal.isIdentStart(next) or
                    (base != 10 and internal.isDigitInBase(next, 16) and !internal.isDigitInBase(next, base)))
                {
                    return .{ .err = core.parseError("intLit", start, "integer literal followed by identifier character", .{
                        .actual = state.input[start .. i + 1],
                        .kind = .syntactic,
                    }) };
                }
            }
            const body = state.input[body_start..i];
            const value = std.fmt.parseInt(i64, body, base) catch {
                return .{ .err = core.parseError("intLit", start, "integer out of range or malformed", .{
                    .actual = state.input[start..i],
                    .kind = .syntactic,
                }) };
            };
            state.index = i;
            return core.ok(value, i);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
