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

/// Structured failure payload returned by every parser primitive.
///
/// Mirrors parsil-TS 3.0's `ParseError` shape so consumers can branch
/// on `parser` identity, read `expected`/`actual` directly, walk
/// `context`, and surface a `hint` without parsing strings.
///
/// String fields (`parser`, `message`, `expected`, `actual`, `hint`,
/// entries of `context`) carry borrowed references — primitives emit
/// string literals (which outlive any parse), so no allocation is
/// required for the basic shape. Phase 1 #20 introduces an arena
/// allocator that owns dynamic `context` slices when `inContext`
/// (#25) wraps a child parser.
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

    /// Single-line fix-it / suggestion ("did you mean …?").
    hint: ?[]const u8 = null,

    /// Outer-first context labels accumulated by `inContext` wrappers.
    /// `&.{ "function call", "argument list" }` reads as
    /// "while parsing a function call's argument list".
    context: []const []const u8 = &.{},

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
/// underline, hint), see `formatParseErrorPretty`.
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
/// source-snippet, caret underline, and an optional hint.
/// Renders something like:
/// ```text
/// ParseError [function call > argument list] @ line 3, col 12 -> str: expected literal
///   |
/// 3 | const x = "missing
///   |            ^^^^^^^ expected 'hello', got 'missing
///   = hint: did you mean to close the string?
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

/// Build a successful `ParseResult(T)` from a value and the cursor
/// position after consumption. `T` is inferred from `value`.
///
/// Example:
/// ```zig
/// state.advance(target.len);
/// return ok(matched_slice, state.index);
/// ```
///
/// Note: parsil-TS exposes a richer set of helpers
/// (`forward(state)`, `updateState(state, index, value)`,
/// `updateResult(state, value)`, `updateError(state, error)`) for its
/// state-transformer model where `ParserState<T, E>` carries the
/// running result. Parsil-Zig deliberately splits `ParseState`
/// (cursor + allocator) from `ParseResult(T)` (the value envelope),
/// so those helpers don't apply — there's no "state with result" to
/// fork or forward. The minimal `ok` constructor is the only sugar
/// the new model wants; the failure path stays as
/// `.{ .err = parseError(...) }` since the explicit struct literal
/// is already concise.
pub fn ok(value: anytype, index: usize) ParseResult(@TypeOf(value)) {
    return .{ .ok = .{ .value = value, .index = index } };
}

/// Cursor over the input string. Carried by every parser invocation.
///
/// `input` is the full slice; `index` is the byte offset of the next
/// character to consume; `allocator` is what slice-producing
/// combinators (`many`, `sepBy`, `sequenceOf`, …) and rich-error
/// helpers (`inContext`) allocate against.
///
/// Convention: caller passes an **arena**, runs the parser, reads
/// the result, then `arena.deinit()` frees everything in bulk. The
/// `Parser(T).runArena` convenience wraps that lifecycle.
pub const ParseState = struct {
    input: []const u8,
    index: usize = 0,
    allocator: std.mem.Allocator,

    /// Build a fresh `ParseState` positioned at the start of `input`.
    pub fn init(input: []const u8, allocator: std.mem.Allocator) ParseState {
        return .{ .input = input, .index = 0, .allocator = allocator };
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

/// Wraps the result of `Parser(T).runArena` together with the arena
/// that owns every slice in it. Caller MUST call `.deinit()` exactly
/// once — that frees the arena and every parser-allocated slice in
/// the result (including any `context` slice on a `ParseError`).
pub fn ArenaResult(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        result: ParseResult(T),

        /// Free the arena and the heap-stored arena handle. After
        /// this, every slice in `result` is dangling.
        pub fn deinit(self: @This()) void {
            const child = self.arena.child_allocator;
            self.arena.deinit();
            child.destroy(self.arena);
        }
    };
}

/// Byte-offset range a parser consumed. `start <= end`; `end - start`
/// is the number of bytes advanced. Passed to the `build` callback in
/// `Parser(T).spanMap`.
pub const Span = struct { start: usize, end: usize };

/// Wraps a parser's success value with the byte offsets it
/// consumed. Returned by `Parser(T).withSpan` and consumed by
/// `Parser(T).spanMap`.
pub fn Spanned(comptime T: type) type {
    return struct { value: T, start: usize, end: usize };
}

/// Generic parser shape. A `Parser(T)` is a comptime-monomorphic
/// function pointer that consumes a `*ParseState` and returns a
/// `ParseResult(T)`.
///
/// Every parser captures its configuration via a comptime closure
/// inside an anonymous struct — see `parsers/str.zig` for the
/// canonical pattern. There is no `*anyopaque` context: each parser
/// invocation resolves to a direct function call at the consumer
/// site.
///
/// **Comptime composition.** The fluent methods on `Parser(T)` —
/// `.map`, `.chain`, `.errorMap`, `.skip`, `.then`, `.between`,
/// `.lookahead`, `.withSpan`, `.spanMap` — all take `comptime self`.
/// Composed parsers must be built at comptime. Runtime-assembled
/// grammars (e.g. mutually recursive ones) use `recursive(thunk)`
/// (#41) instead.
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
        /// `ParseState` from `input` + the caller-supplied
        /// `allocator` and returns the result envelope. Slices that
        /// the parser produces (including in `ParseError.context`)
        /// are allocated via `allocator` — caller owns them.
        pub fn run(self: Self, input: []const u8, allocator: std.mem.Allocator) ParseResult(T) {
            var state = ParseState.init(input, allocator);
            return self.parse(&state);
        }

        /// Convenience: allocates a heap-stored `ArenaAllocator`
        /// backed by `child`, runs the parser inside it, and returns
        /// an `ArenaResult` that owns the arena. Caller MUST call
        /// `.deinit()` on the result exactly once — that frees the
        /// arena and every slice the parser produced.
        ///
        /// Example:
        /// ```zig
        /// var owned = try parser.runArena(input, std.testing.allocator);
        /// defer owned.deinit();
        /// switch (owned.result) {
        ///     .ok => |ok| useValue(ok.value),
        ///     .err => |e| useError(e),
        /// }
        /// ```
        pub fn runArena(
            self: Self,
            input: []const u8,
            child: std.mem.Allocator,
        ) std.mem.Allocator.Error!ArenaResult(T) {
            const arena = try child.create(std.heap.ArenaAllocator);
            arena.* = std.heap.ArenaAllocator.init(child);
            return .{ .arena = arena, .result = self.run(input, arena.allocator()) };
        }

        // ----- Fluent combinator methods (all comptime-self) ---------------

        /// Transform the success value through `fn_map`. Failures
        /// pass through unchanged.
        pub fn map(comptime self: Self, comptime U: type, comptime fn_map: fn (T) U) Parser(U) {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(U) {
                    const r = self.parseFn(state);
                    if (r == .err) return .{ .err = r.err };
                    return ok(fn_map(r.ok.value), r.ok.index);
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Sequence: run `self`, hand its value to `fn_chain` to
        /// produce the next parser, then run that. Failures from
        /// either side propagate. Use when the next parser depends
        /// on the value of the previous one.
        pub fn chain(comptime self: Self, comptime U: type, comptime fn_chain: fn (T) Parser(U)) Parser(U) {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(U) {
                    const r = self.parseFn(state);
                    if (r == .err) return .{ .err = r.err };
                    const next = fn_chain(r.ok.value);
                    return next.parseFn(state);
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Replace the error if `self` fails, otherwise pass through.
        /// Used at consumer-side boundaries (token, statement,
        /// expression) to attach a friendlier message or to reshape
        /// the error for a downstream type system.
        pub fn errorMap(comptime self: Self, comptime fn_err: fn (ParseError) ParseError) Self {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(T) {
                    const r = self.parseFn(state);
                    if (r == .err) return .{ .err = fn_err(r.err) };
                    return r;
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Run `self` then `other`, **keeping `self`'s value** and
        /// discarding `other`'s. Equivalent to
        /// `self.chain(@TypeOf(other).Output, |v| other.map(...))`.
        /// Use to require a trailing delimiter (parse the value, then
        /// skip the closing token).
        pub fn skip(comptime self: Self, comptime other: anytype) Self {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(T) {
                    const r = self.parseFn(state);
                    if (r == .err) return r;
                    const r2 = other.parseFn(state);
                    if (r2 == .err) return .{ .err = r2.err };
                    return ok(r.ok.value, state.index);
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Run `self` then `other`, **keeping `other`'s value** and
        /// discarding `self`'s. Use to parse-and-discard a known
        /// prefix (e.g. a keyword) and keep the following value.
        pub fn then(comptime self: Self, comptime other: anytype) @TypeOf(other) {
            const O = @TypeOf(other);
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(O.Output) {
                    const r = self.parseFn(state);
                    if (r == .err) return .{ .err = r.err };
                    return other.parseFn(state);
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Parse `left`, then `self`, then `right`, keeping only
        /// `self`'s value. Sugar for `left.then(self).skip(right)`.
        /// Typical use: delimited constructs like `( expr )`.
        pub fn between(comptime self: Self, comptime left: anytype, comptime right: anytype) Self {
            return left.then(self).skip(right);
        }

        /// Run `self` non-consuming on success: returns the value
        /// but restores the cursor to where it was before the call.
        /// On failure: passes the error through (cursor also
        /// restored). Use to peek at upcoming structure without
        /// committing to it.
        ///
        /// On success the result's `index` reports the pre-lookahead
        /// position too — semantically "we didn't advance". On
        /// failure the error keeps the inner parser's failure index,
        /// which is what you want for diagnostics.
        pub fn lookahead(comptime self: Self) Self {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(T) {
                    const saved = state.index;
                    const r = self.parseFn(state);
                    state.index = saved;
                    if (r == .err) return .{ .err = r.err };
                    return ok(r.ok.value, saved);
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Wrap the success value in a `Spanned(T) { value, start, end }`
        /// carrying the byte offsets `self` consumed. Failures pass
        /// through unchanged. Foundation for source-position-aware
        /// AST construction.
        pub fn withSpan(comptime self: Self) Parser(Spanned(T)) {
            const Thunk = struct {
                fn parse(state: *ParseState) ParseResult(Spanned(T)) {
                    const start = state.index;
                    const r = self.parseFn(state);
                    if (r == .err) return .{ .err = r.err };
                    return ok(
                        Spanned(T){ .value = r.ok.value, .start = start, .end = state.index },
                        state.index,
                    );
                }
            };
            return .{ .parseFn = &Thunk.parse };
        }

        /// Build a caller-shaped node from `self`'s value plus its
        /// span. Sugar for `self.withSpan().map(U, build)`. Use to
        /// build AST nodes that carry their own source positions.
        pub fn spanMap(
            comptime self: Self,
            comptime U: type,
            comptime build: fn (T, Span) U,
        ) Parser(U) {
            const Thunk = struct {
                fn unwrap(s: Spanned(T)) U {
                    return build(s.value, .{ .start = s.start, .end = s.end });
                }
            };
            return self.withSpan().map(U, Thunk.unwrap);
        }
    };
}
