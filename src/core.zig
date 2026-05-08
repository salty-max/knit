const std = @import("std");

pub const ParseErrorTag = enum {
    UnexpectedEoF,
    ExpectedLiteral,
    Custom,
};

pub const ParseError = struct {
    index: usize,
    msg: []const u8,
    tag: ParseErrorTag,
};

pub fn ParseResult(comptime T: type) type {
    return union(enum) {
        ok: struct {
            value: T,
            index: usize,
        },
        err: ParseError,

        pub fn isOk(self: @This()) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }
    };
}

pub const ParseState = struct {
    input: []const u8,
    index: usize = 0,

    pub fn init(input: []const u8) ParseState {
        return .{ .input = input, .index = 0 };
    }

    pub fn remaining(self: *const ParseState) []const u8 {
        return self.input[self.index..];
    }

    pub fn advance(self: *ParseState, n: usize) void {
        const rem_len = self.input.len - self.index;
        const step = if (n > rem_len) rem_len else n;
        self.index += step;
    }
};

pub fn Parser(comptime T: type) type {
    return struct {
        pub const Output = T;
        const Self = @This();
        const ParseFn = fn (state: *ParseState) ParseResult(T);

        parseFn: *const ParseFn,

        pub fn parse(self: Self, state: *ParseState) ParseResult(T) {
            return self.parseFn(state);
        }

        pub fn run(self: Self, input: []const u8) ParseResult(T) {
            var state = ParseState.init(input);
            return self.parse(&state);
        }
    };
}
