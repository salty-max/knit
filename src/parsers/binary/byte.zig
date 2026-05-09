const core = @import("core");
const internal = @import("internal.zig");

/// Read one byte as `u8`. EOF → `.incomplete`.
pub fn @"u8"() core.Parser(u8) {
    return internal.binaryInt(u8, .little, "binary.u8");
}

/// Read one byte as signed `i8`. EOF → `.incomplete`.
pub fn @"i8"() core.Parser(i8) {
    return internal.binaryInt(i8, .little, "binary.i8");
}
