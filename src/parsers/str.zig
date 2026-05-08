const std = @import("std");
const core = @import("../core.zig");

pub fn str(comptime target: []const u8) core.Parser([]const u8) {
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult([]const u8) {
            const rem = state.remaining();
            if (rem.len < target.len) {
                var matched: usize = 0;
                while (matched < rem.len and rem[matched] == target[matched]) : (matched += 1) {}
                return .{ .err = .{ .index = state.index + matched, .msg = "unexpected end of input", .tag = .UnexpectedEoF } };
            }

            const cand = rem[0..target.len];
            if (!std.mem.eql(u8, cand, target))
                return .{ .err = .{ .index = state.index, .msg = "expected literal", .tag = .ExpectedLiteral } };

            state.advance(target.len);
            return .{ .ok = .{ .value = cand, .index = state.index } };
        }
    };

    return .{ .parseFn = &Thunk.parse };
}
