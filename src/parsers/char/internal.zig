const std = @import("std");
const core = @import("core");

/// Translate a `Utf8DecodeError` into a `ParseError` with the right
/// `kind`, parser identity, and an optional `expected` carried over
/// from the calling parser (so EOF errors still tell consumers what
/// the parser was looking for).
pub fn decodeErrorToParseError(
    err: core.Utf8DecodeError,
    index: usize,
    parser_name: []const u8,
    expected: ?[]const u8,
) core.ParseResult(u21) {
    return switch (err) {
        error.UnexpectedEof => .{ .err = core.parseError(parser_name, index, "unexpected end of input", .{
            .kind = .incomplete,
            .expected = expected,
        }) },
        error.Utf8Invalid => .{ .err = core.parseError(parser_name, index, "invalid UTF-8 sequence", .{
            .kind = .lexical,
            .expected = expected,
        }) },
        error.Utf8Truncated => .{ .err = core.parseError(parser_name, index, "incomplete UTF-8 sequence", .{
            .kind = .incomplete,
            .expected = expected,
        }) },
    };
}

/// Comptime-format a codepoint set as `"<prefix>: 'a', 'b', 'c'"`.
/// Lives in the binary like a string literal — no allocation at
/// runtime. Shared by `oneOf` and `noneOf`.
pub fn formatSet(comptime set: []const u21, comptime prefix: []const u8) []const u8 {
    comptime {
        var total: usize = prefix.len + 2;
        for (set, 0..) |c, i| {
            if (i > 0) total += 2;
            total += 2;
            var b: [4]u8 = undefined;
            // allow-strict: comptime-known set entry; utf8Encode failure here would be a comptime programming error (invalid u21).
            total += std.unicode.utf8Encode(c, &b) catch unreachable;
        }
        var buf: [total]u8 = undefined;
        var pos: usize = 0;
        for (prefix) |b| {
            buf[pos] = b;
            pos += 1;
        }
        buf[pos] = ':';
        pos += 1;
        buf[pos] = ' ';
        pos += 1;
        for (set, 0..) |c, i| {
            if (i > 0) {
                buf[pos] = ',';
                pos += 1;
                buf[pos] = ' ';
                pos += 1;
            }
            buf[pos] = '\'';
            pos += 1;
            var enc: [4]u8 = undefined;
            // allow-strict: same comptime-known invariant as the size-pass loop above.
            const len = std.unicode.utf8Encode(c, &enc) catch unreachable;
            for (0..len) |j| {
                buf[pos] = enc[j];
                pos += 1;
            }
            buf[pos] = '\'';
            pos += 1;
        }
        const final = buf;
        return &final;
    }
}
