//! Test helpers. Imported as `@import("util")` (named module wired in build.zig).
//!
//! Helpers target the rich `ParseError` shape from #19. Phase 1 #20 will
//! introduce arena-allocator-aware variants for tests that need to inspect
//! allocator state.

const std = @import("std");
const P = @import("parsil");

/// Assert the parse succeeded. Returns the success payload for follow-up checks.
pub fn assertOk(comptime T: type, result: P.core.ParseResult(T)) !@TypeOf(result.ok) {
    if (result != .ok) {
        std.debug.print("expected ok, got err: {any}\n", .{result.err});
        return error.UnexpectedErr;
    }
    return result.ok;
}

/// Assert success with an exact value at an exact cursor index.
/// Uses `expectEqualDeep` so slices/tuples/structs all compare structurally.
pub fn assertOkAt(comptime T: type, result: P.core.ParseResult(T), expected_value: T, expected_index: usize) !void {
    const ok = try assertOk(T, result);
    try std.testing.expectEqualDeep(expected_value, ok.value);
    try std.testing.expectEqual(expected_index, ok.index);
}

/// Same as `assertOkAt` but for `[]const u8` results — uses `expectEqualStrings`
/// for clearer diff output on mismatched strings.
pub fn assertOkStrAt(result: P.core.ParseResult([]const u8), expected_value: []const u8, expected_index: usize) !void {
    const ok = try assertOk([]const u8, result);
    try std.testing.expectEqualStrings(expected_value, ok.value);
    try std.testing.expectEqual(expected_index, ok.index);
}

/// Assert the parse failed. Returns the error for follow-up checks.
pub fn assertErr(comptime T: type, result: P.core.ParseResult(T)) !P.core.ParseError {
    if (result == .ok) {
        std.debug.print("expected err, got ok: {any}\n", .{result.ok});
        return error.UnexpectedOk;
    }
    return result.err;
}

/// Assert failure at an exact cursor index, attributed to a specific
/// parser identity (`err.parser`).
pub fn assertErrAt(comptime T: type, result: P.core.ParseResult(T), expected_index: usize, expected_parser: []const u8) !void {
    const err = try assertErr(T, result);
    try std.testing.expectEqual(expected_index, err.index);
    try std.testing.expectEqualStrings(expected_parser, err.parser);
}

/// Assert failure whose `message` field contains the given substring.
pub fn expectErrorMessageContains(comptime T: type, result: P.core.ParseResult(T), needle: []const u8) !void {
    const err = try assertErr(T, result);
    if (std.mem.indexOf(u8, err.message, needle) == null) {
        std.debug.print("expected error message to contain '{s}', got: '{s}'\n", .{ needle, err.message });
        return error.MessageMismatch;
    }
}
