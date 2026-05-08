const std = @import("std");

/// Severity of a `ParseError`. Defaults to `.fatal` — the parse cannot
/// continue. `recoverAt` (#44) and similar combinators promote their
/// captured errors to `.recovered` so consumers can tell synchronized
/// errors apart from terminal ones in a multi-error stream.
pub const Severity = enum {
    fatal,
    recovered,
};

/// Coarse classification of a `ParseError`. The `parser` field
/// disambiguates at fine grain (`"str"` vs `"keyword"` vs …); `kind`
/// answers "what kind of problem is this?" at the granularity LSPs,
/// IDEs, and consumer error handlers care about.
///
/// New variants land here via PR — keep the enum small and meaningful.
pub const ParseErrorKind = enum {
    /// Character / codepoint level: invalid UTF-8, char outside an
    /// expected set, malformed escape inside a string literal.
    lexical,

    /// Structural: missing comma, unclosed bracket, malformed
    /// expression. The default and most common case.
    syntactic,

    /// EOF (or end-of-input sentinel) reached mid-construct. A
    /// specialization of syntactic that LSPs treat differently —
    /// e.g. don't redden while the user is still typing.
    incomplete,

    /// Higher-level constraint violated by a consumer parser: name
    /// not declared, type mismatch, semantic conflict. parsil-zig
    /// itself rarely emits these (mostly consumer-emitted via
    /// `errorMap` at the boundary).
    semantic,

    /// Library bug or invariant violation. Should never reach end
    /// users. Treat as a panic candidate during dev.
    internal,
};

/// Secondary diagnostic note attached to a `ParseError`.
///
/// Notes carry information that's related to but not the primary
/// failure — e.g. "definition of <name> was here" pointing at an
/// earlier line. `index` is optional: notes without a position
/// render as plain prose, with one a caret can underline a region.
pub const Note = struct {
    message: []const u8,
    /// Optional secondary location in the input. When present,
    /// `formatParseErrorPretty` underlines the byte at this offset.
    index: ?usize = null,
    /// Optional fix-it / suggestion attached to this note.
    hint: ?[]const u8 = null,
};

/// Structured failure payload returned by every parser primitive.
///
/// Mirrors parsil-TS 3.0's `ParseError` shape so consumers can branch
/// on `parser` identity, read `expected`/`actual` directly, walk
/// `context`, and surface `notes`/`hint` without parsing strings.
///
/// String fields (`parser`, `message`, `expected`, `actual`, `hint`,
/// entries of `context`, fields of each `Note`) carry borrowed
/// references — primitives emit string literals (which outlive any
/// parse), so no allocation is required for the basic shape.
/// Phase 1 #20 introduces an arena allocator that owns dynamic
/// `context`/`notes` slices when `inContext` (#25) wraps a child
/// parser.
pub const ParseError = struct {
    /// Machine-readable identity of the emitting parser
    /// (`"char"`, `"str"`, `"keyword"`, …).
    parser: []const u8,

    /// Byte offset where the parser refused.
    index: usize,

    /// User-readable description, English-only. No `ParseError @ index N -> X:`
    /// prefix — that's the formatter's job.
    message: []const u8,

    /// What the parser was looking for, when known.
    expected: ?[]const u8 = null,

    /// What was actually at the position, when known.
    actual: ?[]const u8 = null,

    /// Single-line fix-it / suggestion. For richer follow-up notes
    /// (each with their own optional position), use `notes`.
    hint: ?[]const u8 = null,

    /// Outer-first context labels accumulated by `inContext` wrappers.
    /// `&.{ "function call", "argument list" }` reads as
    /// "while parsing a function call's argument list".
    context: []const []const u8 = &.{},

    /// Compiler-style secondary notes. Each note may carry its own
    /// position and hint. The pretty formatter renders them under
    /// the primary error.
    notes: []const Note = &.{},

    /// Severity of the failure — `.fatal` (default) or `.recovered`
    /// (parser synchronized via `recoverAt`).
    severity: Severity = .fatal,

    /// Coarse classification — `.syntactic` by default. See
    /// `ParseErrorKind` for the variant menu.
    kind: ParseErrorKind = .syntactic,
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
        hint: ?[]const u8 = null,
        context: []const []const u8 = &.{},
        notes: []const Note = &.{},
        severity: Severity = .fatal,
        kind: ParseErrorKind = .syntactic,
    },
) ParseError {
    return .{
        .parser = parser,
        .index = index,
        .message = message,
        .expected = extras.expected,
        .actual = extras.actual,
        .hint = extras.hint,
        .context = extras.context,
        .notes = extras.notes,
        .severity = extras.severity,
        .kind = extras.kind,
    };
}

/// 1-indexed line and column derived from a byte offset into `input`.
pub const LineCol = struct { line: usize, col: usize };

/// Convert a byte offset into a 1-indexed `(line, col)` pair.
///
/// `\n` ends a line. CRLF inputs produce one `line` increment per
/// `\n` (the `\r` adds a column then the `\n` resets it — acceptable
/// for diagnostic display). Pre-OS-X classic-Mac `\r`-only line
/// endings are NOT recognised.
///
/// `index` past the end of `input` clamps to the last byte.
pub fn linecol(input: []const u8, index: usize) LineCol {
    var line: usize = 1;
    var col: usize = 1;
    var i: usize = 0;
    const upto = if (index > input.len) input.len else index;
    while (i < upto) : (i += 1) {
        if (input[i] == '\n') {
            line += 1;
            col = 1;
        } else {
            col += 1;
        }
    }
    return .{ .line = line, .col = col };
}

/// Format a `ParseError` into the conventional one-line display
/// `ParseError [outer > inner] @ index N -> <parser>: <message>`.
/// The context bracket is omitted when there is no context.
///
/// For the multi-line caret-and-snippet form (line/col, source
/// underline, notes), see `formatParseErrorPretty`.
///
/// The returned string is allocated via `allocator` — caller owns
/// and must `free` it.
pub fn formatParseError(allocator: std.mem.Allocator, err: ParseError) ![]u8 {
    if (err.context.len == 0) {
        return try std.fmt.allocPrint(
            allocator,
            "ParseError @ index {d} -> {s}: {s}",
            .{ err.index, err.parser, err.message },
        );
    }

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

/// Format a `ParseError` as a multi-line diagnostic with line/col,
/// source-snippet, caret underline, and optional hint and notes.
/// Renders something like:
/// ```text
/// ParseError [function call > argument list] @ line 3, col 12 -> str: expected literal
///   |
/// 3 | const x = "missing
///   |            ^^^^^^^ expected "hello", got "missing
///   = hint: did you mean to close the string?
///   note: definition was here
///     |
///   1 | const hello = "hello";
///     |               ^^^^^^^
/// ```
///
/// The returned string is allocated via `allocator` — caller owns
/// and must `free` it.
pub fn formatParseErrorPretty(
    allocator: std.mem.Allocator,
    input: []const u8,
    err: ParseError,
) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    const lc = linecol(input, err.index);
    try writeHeader(&buf, allocator, err, lc);
    try writeSnippet(&buf, allocator, input, err.index, lc, err.expected, err.actual);

    if (err.hint) |h| {
        const gutter = digitWidth(lc.line);
        try writeSpaces(&buf, allocator, gutter);
        try buf.print(allocator, " = hint: {s}\n", .{h});
    }

    for (err.notes) |note| {
        try buf.print(allocator, "  note: {s}\n", .{note.message});
        if (note.index) |ni| {
            const note_lc = linecol(input, ni);
            try writeSnippet(&buf, allocator, input, ni, note_lc, null, null);
        }
        if (note.hint) |nh| {
            const gutter = if (note.index) |ni| digitWidth(linecol(input, ni).line) else 1;
            try writeSpaces(&buf, allocator, gutter);
            try buf.print(allocator, " = hint: {s}\n", .{nh});
        }
    }

    return try buf.toOwnedSlice(allocator);
}

fn writeHeader(
    buf: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    err: ParseError,
    lc: LineCol,
) !void {
    try buf.appendSlice(allocator, "ParseError");
    if (err.context.len > 0) {
        try buf.appendSlice(allocator, " [");
        for (err.context, 0..) |label, i| {
            if (i > 0) try buf.appendSlice(allocator, " > ");
            try buf.appendSlice(allocator, label);
        }
        try buf.appendSlice(allocator, "]");
    }
    try buf.print(allocator, " @ line {d}, col {d} -> {s}: {s}\n", .{
        lc.line, lc.col, err.parser, err.message,
    });
}

fn writeSnippet(
    buf: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    input: []const u8,
    index: usize,
    lc: LineCol,
    expected: ?[]const u8,
    actual: ?[]const u8,
) !void {
    const line_start = lineStartFrom(input, index);
    const line_end = lineEndFrom(input, index);
    const source = input[line_start..line_end];
    const caret_col = if (index >= line_start) index - line_start else 0;

    const underline_len: usize = blk: {
        if (expected) |e| break :blk @max(e.len, 1);
        if (actual) |a| break :blk @max(a.len, 1);
        break :blk 1;
    };

    const gutter = digitWidth(lc.line);

    // Empty gutter line: "   |"
    try writeSpaces(buf, allocator, gutter);
    try buf.appendSlice(allocator, " |\n");

    // Source line: "N | <source>"
    try buf.print(allocator, "{d} | {s}\n", .{ lc.line, source });

    // Caret line: "  |    ^^^^ expected 'X', got 'Y'"
    try writeSpaces(buf, allocator, gutter);
    try buf.appendSlice(allocator, " | ");
    try writeSpaces(buf, allocator, caret_col);
    try writeChars(buf, allocator, '^', underline_len);

    if (expected != null or actual != null) {
        try buf.appendSlice(allocator, " ");
        if (expected) |e| {
            try buf.print(allocator, "expected '{s}'", .{e});
        }
        if (expected != null and actual != null) {
            try buf.appendSlice(allocator, ", ");
        }
        if (actual) |a| {
            try buf.print(allocator, "got '{s}'", .{a});
        }
    }
    try buf.appendSlice(allocator, "\n");
}

fn lineStartFrom(input: []const u8, index: usize) usize {
    var i = if (index > input.len) input.len else index;
    while (i > 0) : (i -= 1) {
        if (input[i - 1] == '\n') return i;
    }
    return 0;
}

fn lineEndFrom(input: []const u8, index: usize) usize {
    var i = if (index > input.len) input.len else index;
    while (i < input.len) : (i += 1) {
        if (input[i] == '\n') return i;
    }
    return input.len;
}

fn digitWidth(n: usize) usize {
    if (n == 0) return 1;
    var x = n;
    var w: usize = 0;
    while (x > 0) : (x /= 10) w += 1;
    return w;
}

fn writeSpaces(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) try buf.append(allocator, ' ');
}

fn writeChars(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, c: u8, n: usize) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) try buf.append(allocator, c);
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
