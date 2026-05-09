const std = @import("std");
const core = @import("core");

/// Byte-order tag for the binary numeric parsers. Mirrors
/// `std.builtin.Endian` but lives here so the parsil API stays
/// self-contained (consumers don't need to import std to spell
/// out the endianness in a comptime construction).
pub const Endian = enum {
    little,
    big,

    fn toStd(self: Endian) std.builtin.Endian {
        return switch (self) {
            .little => .little,
            .big => .big,
        };
    }
};

/// Read a fixed-width integer of type `T` at the cursor in the
/// specified `endian` byte order. Advances the cursor by
/// `@sizeOf(T)` bytes on success; returns `.incomplete` on EOF
/// before the full width is available.
///
/// Used internally by the public `u8 / i8 / u16le / ... / i64be`
/// parsers — each is a single-line alias around this helper.
pub fn binaryInt(comptime T: type, comptime endian: Endian, comptime parser_name: []const u8) core.Parser(T) {
    const bytes = @sizeOf(T);
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            if (state.index + bytes > state.input.len) {
                return .{ .err = core.parseError(parser_name, state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const slice = state.input[state.index..][0..bytes];
            const value = std.mem.readInt(T, slice, endian.toStd());
            state.advance(bytes);
            return core.ok(value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}

/// Read a fixed-width IEEE-754 float of type `T` (`f32` or
/// `f64`) at the cursor in the specified `endian` byte order.
/// Internally reads the backing integer (`u32` / `u64`) and
/// `@bitCast`s to the float — preserves all bit-pattern
/// invariants (NaN, denormals, etc.).
pub fn binaryFloat(comptime T: type, comptime endian: Endian, comptime parser_name: []const u8) core.Parser(T) {
    const BackingInt = if (T == f32) u32 else if (T == f64) u64 else @compileError("binaryFloat: T must be f32 or f64, got " ++ @typeName(T));
    const bytes = @sizeOf(T);
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            if (state.index + bytes > state.input.len) {
                return .{ .err = core.parseError(parser_name, state.index, "unexpected end of input", .{
                    .kind = .incomplete,
                }) };
            }
            const slice = state.input[state.index..][0..bytes];
            const bits = std.mem.readInt(BackingInt, slice, endian.toStd());
            // safety: `bits` IS the IEEE-754 bit pattern of T at the requested endianness; @bitCast reinterprets the bits without changing them.
            const value: T = @bitCast(bits);
            state.advance(bytes);
            return core.ok(value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
