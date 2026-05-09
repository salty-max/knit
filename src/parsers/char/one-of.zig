const core = @import("core");
const char_mod = @import("char.zig");

/// Match a single UTF-8 codepoint that appears in `set`.
///
/// Example:
/// ```zig
/// const vowel = comptime oneOf(&.{ 'a', 'e', 'i', 'o', 'u' });
/// // vowel.run("apple", alloc) → ok = .{ .value = 'a', .index = 1 }
/// // vowel.run("xyz", alloc) → err with parser = "oneOf"
/// ```
pub fn oneOf(comptime set: []const u21) core.Parser(u21) {
    const Thunk = struct {
        const expected_str = formatSet(set, "one of");

        fn parse(state: *core.ParseState) core.ParseResult(u21) {
            const decoded = core.decodeNext(state) catch |err| return char_mod.decodeErrorToParseError(err, state.index, "oneOf", expected_str);
            for (set) |c| {
                if (decoded.cp == c) {
                    state.advance(decoded.width);
                    return core.ok(decoded.cp, state.index);
                }
            }
            return .{ .err = core.parseError("oneOf", state.index, "codepoint not in set", .{
                .expected = expected_str,
                .actual = core.encodeCpAlloc(state.allocator, decoded.cp),
                .kind = .syntactic,
            }) };
        }
    };
    return .{ .parseFn = &Thunk.parse };
}

/// Comptime-format a codepoint set as `"<prefix>: 'a', 'b', 'c'"`.
/// Lives in the binary like a string literal — no allocation at
/// runtime. Shared by `oneOf` and `noneOf` (sibling-imported via
/// `formatSet` exposed by this file).
pub fn formatSet(comptime set: []const u21, comptime prefix: []const u8) []const u8 {
    const std = @import("std");
    comptime {
        // First pass: total bytes
        var total: usize = prefix.len + 2; // prefix + ": "
        for (set, 0..) |c, i| {
            if (i > 0) total += 2; // ", "
            total += 2; // wrapping single quotes
            var b: [4]u8 = undefined;
            // allow-strict: comptime-known set entry; utf8Encode failure here would be a comptime programming error (invalid u21).
            total += std.unicode.utf8Encode(c, &b) catch unreachable;
        }
        // Second pass: build into a sized array
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
