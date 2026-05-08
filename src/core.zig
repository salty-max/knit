const std = @import("std");

/// Categorical tag attached to every `ParseError`.
///
/// Phase 1 #19 will replace this with a richer `parser` identity field.
/// Until then, three coarse categories cover the current parser set.
pub const ParseErrorTag = enum {
    UnexpectedEoF,
    ExpectedLiteral,
    Custom,
};

/// Failure payload returned by every parser primitive.
///
/// `index` points at the first byte the parser refused; `msg` is a
/// short English description suitable for logging. Phase 1 #19
/// extends this with `parser`, `expected`, `actual`, and `context`.
pub const ParseError = struct {
    index: usize,
    msg: []const u8,
    tag: ParseErrorTag,
};

/// The result envelope every parser returns.
///
/// On success: `.ok = .{ .value: T, .index: usize }` — the cursor
/// after consumption. On failure: `.err = ParseError` — the cursor
/// at the point of refusal.
pub fn ParseResult(comptime T: type) type {
    return union(enum) {
        ok: struct {
            value: T,
            index: usize,
        },
        err: ParseError,

        /// Type guard narrowing the union to its `.ok` arm.
        ///
        /// Tests in this repo use the direct `result == .ok` pattern;
        /// `isOk` is exported for consumers who prefer the method form
        /// (mirrors parsil-TS's `isOk` / `isError` guards).
        // allow-unused: public type guard; tests use direct '== .ok' pattern,
        // but consumers can call `.isOk()`. Mirrors parsil-TS's type guards.
        pub fn isOk(self: @This()) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }
    };
}

/// Cursor over the input string. Carried by every parser invocation.
///
/// `input` is the full slice; `index` is the byte offset of the next
/// character to consume. Phase 1 #20 will add an arena `allocator`
/// field for combinators that produce slices.
pub const ParseState = struct {
    input: []const u8,
    index: usize = 0,

    /// Build a fresh `ParseState` positioned at the start of `input`.
    pub fn init(input: []const u8) ParseState {
        return .{ .input = input, .index = 0 };
    }

    /// The unconsumed tail of the input — the slice from `index` to
    /// the end. Cheap (no allocation, just a sub-slice).
    pub fn remaining(self: *const ParseState) []const u8 {
        return self.input[self.index..];
    }

    /// Advance the cursor by `n` bytes. Clamps to the end of input
    /// (overflow-safe), so callers don't have to bounds-check.
    pub fn advance(self: *ParseState, n: usize) void {
        const rem_len = self.input.len - self.index;
        const step = if (n > rem_len) rem_len else n;
        self.index += step;
    }
};

/// Generic parser shape. A `Parser(T)` is a comptime-monomorphic
/// function pointer that consumes a `*ParseState` and returns a
/// `ParseResult(T)`.
///
/// Every parser captures its configuration via a comptime closure
/// inside an anonymous struct — see `parsers/str.zig` for the
/// canonical pattern. There is no `*anyopaque` context: each parser
/// invocation resolves to a direct function call at the consumer
/// site.
pub fn Parser(comptime T: type) type {
    return struct {
        /// Convenience type alias so consumers can write
        /// `SomeParser.Output` to extract the success-payload type.
        // allow-unused: type-extraction helper; used by Phase 1 combinators (#22)
        pub const Output = T;
        const Self = @This();
        const ParseFn = fn (state: *ParseState) ParseResult(T);

        parseFn: *const ParseFn,

        /// Run the parser against an existing state. Used internally
        /// when composing parsers; consumers usually call `.run`.
        pub fn parse(self: Self, state: *ParseState) ParseResult(T) {
            return self.parseFn(state);
        }

        /// Run the parser against a fresh input string. Builds a
        /// `ParseState` internally and returns the result envelope.
        pub fn run(self: Self, input: []const u8) ParseResult(T) {
            var state = ParseState.init(input);
            return self.parse(&state);
        }
    };
}
