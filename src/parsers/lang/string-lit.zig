const std = @import("std");
const core = @import("core");

/// Match a double-quoted string literal with C-style escape
/// sequences. Returns the **decoded** byte slice (escapes
/// processed) allocated via `state.allocator` — caller owns
/// the slice (canonical arena-per-parse cleanup).
///
/// Recognised escapes:
/// - `\n` → 0x0A (LF)
/// - `\t` → 0x09 (HT)
/// - `\r` → 0x0D (CR)
/// - `\\` → 0x5C (`\`)
/// - `\"` → 0x22 (`"`)
/// - `\xHH` → byte HH (two hex digits, case-insensitive)
///
/// **Allocates.** Unlike most parsil parsers, `stringLit` cannot
/// borrow from `state.input` because the decoded form differs
/// from the source bytes. Use `runArena` so the slice is reclaimed
/// in bulk on `.deinit()`.
///
/// Failure shapes:
/// - Missing opening `"` → `.syntactic`
/// - Unterminated string (EOF before closing `"`) → `.incomplete`
/// - Unterminated escape (EOF after `\`) → `.incomplete`
/// - Incomplete `\xHH` (EOF mid-hex) → `.incomplete`
/// - Bad hex digit in `\xHH` → `.lexical`
/// - Unknown escape sequence (e.g. `\z`) → `.syntactic`
///
/// Example:
/// ```zig
/// const s = comptime stringLit();
/// // s.run("\"hello\"",     a) → ok = .{ .value = "hello",  .index = 7 }
/// // s.run("\"a\\nb\"",     a) → ok = .{ .value = "a\nb",   .index = 6 }
/// // s.run("\"\\x41\"",     a) → ok = .{ .value = "A",      .index = 6 }
/// // s.run("\"unterminated", a) → err with kind = .incomplete
/// ```
pub fn stringLit() core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            if (state.index >= state.input.len or state.input[state.index] != '"') {
                return .{ .err = core.parseError("stringLit", state.index, "expected '\"' to open string", .{
                    .expected = "\"",
                    .kind = .syntactic,
                }) };
            }
            state.advance(1);
            // Note: no `errdefer buf.deinit` here — ParseResult is a
            // plain union, not an error union, so errdefer doesn't
            // fire on the `.err` returns. Each err branch frees `buf`
            // explicitly before returning.
            var buf: std.ArrayList(u8) = .empty;
            while (state.index < state.input.len) {
                const b = state.input[state.index];
                if (b == '"') {
                    state.advance(1);
                    const owned: []const u8 = buf.toOwnedSlice(state.allocator) catch {
                        return .{ .err = core.parseError("stringLit", state.index, "out of memory finalising string", .{
                            .kind = .internal,
                        }) };
                    };
                    return core.ok(owned, state.index);
                }
                if (b == '\\') {
                    state.advance(1);
                    if (state.index >= state.input.len) {
                        buf.deinit(state.allocator);
                        return .{ .err = core.parseError("stringLit", state.index, "unterminated escape sequence", .{
                            .kind = .incomplete,
                        }) };
                    }
                    const esc = state.input[state.index];
                    state.advance(1);
                    const decoded: u8 = switch (esc) {
                        'n' => '\n',
                        't' => '\t',
                        'r' => '\r',
                        '\\' => '\\',
                        '"' => '"',
                        'x' => blk: {
                            if (state.index + 2 > state.input.len) {
                                buf.deinit(state.allocator);
                                return .{ .err = core.parseError("stringLit", state.index, "incomplete '\\xHH' escape", .{
                                    .kind = .incomplete,
                                }) };
                            }
                            const hi = std.fmt.charToDigit(state.input[state.index], 16) catch {
                                buf.deinit(state.allocator);
                                return .{ .err = core.parseError("stringLit", state.index, "bad hex digit in '\\xHH' escape", .{
                                    .kind = .lexical,
                                }) };
                            };
                            const lo = std.fmt.charToDigit(state.input[state.index + 1], 16) catch {
                                buf.deinit(state.allocator);
                                return .{ .err = core.parseError("stringLit", state.index + 1, "bad hex digit in '\\xHH' escape", .{
                                    .kind = .lexical,
                                }) };
                            };
                            state.advance(2);
                            break :blk @intCast(hi * 16 + lo);
                        },
                        else => {
                            buf.deinit(state.allocator);
                            return .{ .err = core.parseError("stringLit", state.index - 1, "unknown escape sequence", .{
                                .kind = .syntactic,
                            }) };
                        },
                    };
                    buf.append(state.allocator, decoded) catch {
                        return .{ .err = core.parseError("stringLit", state.index, "out of memory while decoding string", .{
                            .kind = .internal,
                        }) };
                    };
                } else {
                    buf.append(state.allocator, b) catch {
                        return .{ .err = core.parseError("stringLit", state.index, "out of memory while decoding string", .{
                            .kind = .internal,
                        }) };
                    };
                    state.advance(1);
                }
            }
            buf.deinit(state.allocator);
            return .{ .err = core.parseError("stringLit", state.index, "unterminated string literal", .{
                .kind = .incomplete,
            }) };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
