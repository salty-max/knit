const core = @import("core");
const internal = @import("internal.zig");

/// Read a little-endian `u16` (2 bytes). EOF → `.incomplete`.
pub fn u16le() core.Parser(u16) {
    return internal.binaryInt(u16, .little, "binary.u16le");
}

/// Read a big-endian `u16` (2 bytes). EOF → `.incomplete`.
pub fn u16be() core.Parser(u16) {
    return internal.binaryInt(u16, .big, "binary.u16be");
}

/// Read a little-endian signed `i16` (2 bytes). EOF → `.incomplete`.
pub fn i16le() core.Parser(i16) {
    return internal.binaryInt(i16, .little, "binary.i16le");
}

/// Read a big-endian signed `i16` (2 bytes). EOF → `.incomplete`.
pub fn i16be() core.Parser(i16) {
    return internal.binaryInt(i16, .big, "binary.i16be");
}
