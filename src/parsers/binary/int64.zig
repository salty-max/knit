const core = @import("core");
const internal = @import("internal.zig");

/// Read a little-endian `u64` (8 bytes). EOF → `.incomplete`.
pub fn u64le() core.Parser(u64) {
    return internal.binaryInt(u64, .little, "binary.u64le");
}

/// Read a big-endian `u64` (8 bytes). EOF → `.incomplete`.
pub fn u64be() core.Parser(u64) {
    return internal.binaryInt(u64, .big, "binary.u64be");
}

/// Read a little-endian signed `i64` (8 bytes). EOF → `.incomplete`.
pub fn i64le() core.Parser(i64) {
    return internal.binaryInt(i64, .little, "binary.i64le");
}

/// Read a big-endian signed `i64` (8 bytes). EOF → `.incomplete`.
pub fn i64be() core.Parser(i64) {
    return internal.binaryInt(i64, .big, "binary.i64be");
}
