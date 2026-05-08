const std = @import("std");

/// Structured failure payload returned by every parser primitive.
///
/// Mirrors parsil-TS 3.0's `ParseError` shape so consumers can branch
/// on `parser` identity, read `expected`/`actual` directly, and walk
/// `context` without parsing strings.
///
/// String fields (`parser`, `message`, entries of `context`,
/// `expected`, `actual`) carry borrowed references — primitives emit
/// string literals (which outlive any parse), so no allocation is
/// required for the basic shape. Phase 1 #20 introduces an arena
/// allocator that owns dynamic context slices when `inContext`
/// (#25) wraps a child parser.
pub const ParseError = struct {
    /// Machine-readable identity of the emitting parser
    /// (`"char"`, `"str"`, `"keyword"`, …).
    parser: []const u8,

    /// Byte offset where the parser refused.
    index: usize,

    /// User-readable description, English-only. No `ParseError @ index N -> X:`
    /// prefix — that's `formatParseError`'s job.
    message: []const u8,

    /// What the parser was looking for, when known.
    expected: ?[]const u8 = null,

    /// What was actually at the position, when known.
    actual: ?[]const u8 = null,

    /// Outer-first context labels accumulated by `inContext` wrappers.
    /// `&.{ "function call", "argument list" }` reads as
    /// "while parsing a function call's argument list".
    context: []const []const u8 = &.{},
};

/// Convenience factory for building `ParseError` objects inside parser
/// primitives. Equivalent to spelling out the struct literal but
/// compresses the common case.
///
/// Example:
/// ```zig
/// return updateError(state, parseError("char", state.index,
///     "expected codepoint",
///     .{ .expected = "'a'", .actual = next_char_str },
/// ));
/// ```
pub fn parseError(
    parser: []const u8,
    index: usize,
    message: []const u8,
    extras: struct {
        expected: ?[]const u8 = null,
        actual: ?[]const u8 = null,
        context: []const []const u8 = &.{},
    },
) ParseError {
    return .{
        .parser = parser,
        .index = index,
        .message = message,
        .expected = extras.expected,
        .actual = extras.actual,
        .context = extras.context,
    };
}

/// Format a `ParseError` into the conventional display string
/// `ParseError [outer > inner] @ index N -> <parser>: <message>`.
/// The context bracket is omitted when there is no context.
///
/// The returned string is allocated via `allocator` — caller owns and
/// must `free` it.
pub fn formatParseError(allocator: std.mem.Allocator, err: ParseError) ![]u8 {
    if (err.context.len == 0) {
        return try std.fmt.allocPrint(
            allocator,
            "ParseError @ index {d} -> {s}: {s}",
            .{ err.index, err.parser, err.message },
        );
    }

    // Build the context bracket: " [outer > inner]"
    var ctx_buf: std.ArrayList(u8) = .empty;
    defer ctx_buf.deinit(allocator);
    try ctx_buf.appendSlice(allocator, " [");
    for (err.context, 0..) |label, i| {
        if (i > 0) try ctx_buf.appendSlice(allocator, " > ");
        try ctx_buf.appendSlice(allocator, label);
    }
    try ctx_buf.appendSlice(allocator, "]");

    return try std.fmt.allocPrint(
        allocator,
        "ParseError{s} @ index {d} -> {s}: {s}",
        .{ ctx_buf.items, err.index, err.parser, err.message },
    );
}

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
