const core = @import("core");
const internal = @import("internal.zig");

/// Read a little-endian `u32` (4 bytes). EOF → `.incomplete`.
pub fn u32le() core.Parser(u32) {
    return internal.binaryInt(u32, .little, "binary.u32le");
}

/// Read a big-endian `u32` (4 bytes). EOF → `.incomplete`.
pub fn u32be() core.Parser(u32) {
    return internal.binaryInt(u32, .big, "binary.u32be");
}

/// Read a little-endian signed `i32` (4 bytes). EOF → `.incomplete`.
pub fn i32le() core.Parser(i32) {
    return internal.binaryInt(i32, .little, "binary.i32le");
}

/// Read a big-endian signed `i32` (4 bytes). EOF → `.incomplete`.
pub fn i32be() core.Parser(i32) {
    return internal.binaryInt(i32, .big, "binary.i32be");
}
