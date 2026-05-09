const core = @import("core");
const internal = @import("internal.zig");

/// Read a little-endian IEEE-754 `f32` (4 bytes). EOF → `.incomplete`.
pub fn f32le() core.Parser(f32) {
    return internal.binaryFloat(f32, .little, "binary.f32le");
}

/// Read a big-endian IEEE-754 `f32` (4 bytes). EOF → `.incomplete`.
pub fn f32be() core.Parser(f32) {
    return internal.binaryFloat(f32, .big, "binary.f32be");
}

/// Read a little-endian IEEE-754 `f64` (8 bytes). EOF → `.incomplete`.
pub fn f64le() core.Parser(f64) {
    return internal.binaryFloat(f64, .little, "binary.f64le");
}

/// Read a big-endian IEEE-754 `f64` (8 bytes). EOF → `.incomplete`.
pub fn f64be() core.Parser(f64) {
    return internal.binaryFloat(f64, .big, "binary.f64be");
}
