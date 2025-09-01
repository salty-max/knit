const std = @import("std");
const P = @import("parsil"); // provided by build.zig

test "module loads" {
    _ = P;
}

// Include additional test files under tests/
test {
    _ = @import("tests/str.test.zig");
}
