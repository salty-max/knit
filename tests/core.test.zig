const std = @import("std");
const P = @import("parsil");

// --- Parser(T) fluent methods -------------------------------------------

const a = std.testing.allocator;

test "Parser.map: transforms ok value through fn" {
    const upper = comptime P.str("hi").map(usize, struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    }.len);
    const r = upper.run("hi there", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(usize, 2), r.ok.value);
}

test "Parser.map: forwards err unchanged" {
    const upper = comptime P.str("hi").map(usize, struct {
        fn len(s: []const u8) usize {
            return s.len;
        }
    }.len);
    const r = upper.run("nope", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("str", r.err.parser);
}

test "Parser.chain: feeds value into a follow-up parser" {
    // After matching "say:", run str("hello"). Demonstrates chain even if the
    // 'next parser' is constant — picks up parser-via-fn-return semantics.
    const composed = comptime P.str("say:").chain([]const u8, struct {
        fn next(_: []const u8) P.core.Parser([]const u8) {
            return P.str("hello");
        }
    }.next);
    const r = composed.run("say:hello", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value);
}

test "Parser.errorMap: replaces the error" {
    const wrapped = comptime P.str("hi").errorMap(struct {
        fn map(_: P.core.ParseError) P.core.ParseError {
            return P.core.parseError("custom", 0, "boundary error", .{});
        }
    }.map);
    const r = wrapped.run("nope", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqualStrings("custom", r.err.parser);
    try std.testing.expectEqualStrings("boundary error", r.err.message);
}

test "Parser.skip: keeps self's value, advances past other" {
    const composed = comptime P.str("hello").skip(P.str("!"));
    const r = composed.run("hello!", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value);
    try std.testing.expectEqual(@as(usize, 6), r.ok.index);
}

test "Parser.then: keeps other's value" {
    const composed = comptime P.str("Mr.").then(P.str(" Bond"));
    const r = composed.run("Mr. Bond", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings(" Bond", r.ok.value);
}

test "Parser.between: parses left + self + right, keeps self" {
    const inside = comptime P.str("x").between(P.str("("), P.str(")"));
    const r = inside.run("(x)", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("x", r.ok.value);
}

test "Parser.lookAhead: succeeds without consuming" {
    const peek = comptime P.str("hi").lookAhead();
    const r = peek.run("hi there", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hi", r.ok.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.index);
}

test "Parser.lookAhead: forwards err with cursor restored" {
    const peek = comptime P.str("hi").lookAhead();
    const r = peek.run("bye", a);
    try std.testing.expect(r == .err);
    try std.testing.expectEqual(@as(usize, 0), r.err.index);
}

test "Parser.withSpan: wraps value with start/end byte offsets" {
    const spanned = comptime P.str("hello").withSpan();
    const r = spanned.run("hello world", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value.value);
    try std.testing.expectEqual(@as(usize, 0), r.ok.value.start);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value.end);
}

test "Parser.spanMap: builds caller-shaped node from value + span" {
    const Node = struct { tag: []const u8, len: usize };
    const node = comptime P.str("hello").spanMap(Node, struct {
        fn build(v: []const u8, loc: P.core.Span) Node {
            return .{ .tag = v, .len = loc.end - loc.start };
        }
    }.build);
    const r = node.run("hello world", a);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value.tag);
    try std.testing.expectEqual(@as(usize, 5), r.ok.value.len);
}

// --- parseError factory --------------------------------------------------

test "parseError: factory builds the rich shape with defaults" {
    const e = P.core.parseError("char", 5, "expected codepoint", .{});
    try std.testing.expectEqualStrings("char", e.parser);
    try std.testing.expectEqual(@as(usize, 5), e.index);
    try std.testing.expectEqualStrings("expected codepoint", e.message);
    try std.testing.expect(e.expected == null);
    try std.testing.expect(e.actual == null);
    try std.testing.expect(e.hint == null);
    try std.testing.expectEqual(@as(usize, 0), e.context.len);
}

test "parseError: factory carries expected and actual" {
    const e = P.core.parseError("str", 0, "expected literal", .{
        .expected = "hello",
        .actual = "world",
    });
    try std.testing.expectEqualStrings("hello", e.expected.?);
    try std.testing.expectEqualStrings("world", e.actual.?);
}

test "parseError: factory defaults severity=.fatal and kind=.syntactic" {
    const e = P.core.parseError("str", 0, "boom", .{});
    try std.testing.expectEqual(P.core.Severity.fatal, e.severity);
    try std.testing.expectEqual(P.core.ParseErrorKind.syntactic, e.kind);
}

test "parseError: factory carries severity and kind" {
    const e = P.core.parseError("str", 0, "ran out", .{
        .kind = .incomplete,
        .severity = .recovered,
    });
    try std.testing.expectEqual(P.core.Severity.recovered, e.severity);
    try std.testing.expectEqual(P.core.ParseErrorKind.incomplete, e.kind);
}

test "parseError: factory carries hint" {
    const e = P.core.parseError("ident", 5, "name conflict", .{
        .hint = "did you mean 'foo'?",
    });
    try std.testing.expectEqualStrings("did you mean 'foo'?", e.hint.?);
}

// --- formatParseError (one-line) ----------------------------------------

test "formatParseError: minimal shape" {
    const e = P.core.parseError("str", 5, "expected literal", .{});
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("ParseError @ index 5 -> str: expected literal", s);
}

test "formatParseError: with single-level context" {
    const e: P.core.ParseError = .{
        .parser = "expr",
        .index = 12,
        .message = "expected operand",
        .context = &.{"function call"},
    };
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings("ParseError [function call] @ index 12 -> expr: expected operand", s);
}

test "formatParseError: nested context joined outer-first with ' > '" {
    const e: P.core.ParseError = .{
        .parser = "expr",
        .index = 12,
        .message = "expected operand",
        .context = &.{ "function call", "argument list", "expression" },
    };
    const s = try P.core.formatParseError(std.testing.allocator, e);
    defer std.testing.allocator.free(s);
    try std.testing.expectEqualStrings(
        "ParseError [function call > argument list > expression] @ index 12 -> expr: expected operand",
        s,
    );
}

// --- linecol -------------------------------------------------------------

test "linecol: start of input is line 1, col 1" {
    const lc = P.core.linecol("hello", 0);
    try std.testing.expectEqual(@as(usize, 1), lc.line);
    try std.testing.expectEqual(@as(usize, 1), lc.col);
}

test "linecol: mid-line on first line" {
    const lc = P.core.linecol("hello world", 6);
    try std.testing.expectEqual(@as(usize, 1), lc.line);
    try std.testing.expectEqual(@as(usize, 7), lc.col);
}

test "linecol: second line via \\n" {
    const lc = P.core.linecol("abc\ndef", 5);
    try std.testing.expectEqual(@as(usize, 2), lc.line);
    try std.testing.expectEqual(@as(usize, 2), lc.col);
}

test "linecol: index past end clamps to last byte" {
    const lc = P.core.linecol("abc\ndef", 100);
    try std.testing.expectEqual(@as(usize, 2), lc.line);
    try std.testing.expectEqual(@as(usize, 4), lc.col);
}

test "linecol: empty input is line 1, col 1" {
    const lc = P.core.linecol("", 0);
    try std.testing.expectEqual(@as(usize, 1), lc.line);
    try std.testing.expectEqual(@as(usize, 1), lc.col);
}

// --- formatParseErrorPretty ---------------------------------------------

test "formatParseErrorPretty: single-line input renders header + snippet + caret" {
    const input = "hello world";
    const err = P.core.parseError("str", 6, "expected literal", .{
        .expected = "ZZZZZ",
        .actual = "world",
    });
    const s = try P.core.formatParseErrorPretty(std.testing.allocator, input, err);
    defer std.testing.allocator.free(s);

    const expected =
        "ParseError @ line 1, col 7 -> str: expected literal\n" ++
        "  |\n" ++
        "1 | hello world\n" ++
        "  |       ^^^^^ expected 'ZZZZZ', got 'world'\n";
    try std.testing.expectEqualStrings(expected, s);
}

test "formatParseErrorPretty: multi-line input picks the offending line" {
    const input = "line one\nline two\nthird line";
    // Index 9 is the 'l' of "line two"
    const err = P.core.parseError("str", 9, "boom", .{});
    const s = try P.core.formatParseErrorPretty(std.testing.allocator, input, err);
    defer std.testing.allocator.free(s);

    const expected =
        "ParseError @ line 2, col 1 -> str: boom\n" ++
        "  |\n" ++
        "2 | line two\n" ++
        "  | ^\n";
    try std.testing.expectEqualStrings(expected, s);
}

// --- ok constructor -----------------------------------------------------

test "ok: builds a ParseResult(T) with T inferred from value" {
    const r = P.core.ok(@as([]const u8, "hello"), 5);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hello", r.ok.value);
    try std.testing.expectEqual(@as(usize, 5), r.ok.index);
}

test "ok: works for non-string T" {
    const r = P.core.ok(@as(u32, 42), 4);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqual(@as(u32, 42), r.ok.value);
    try std.testing.expectEqual(@as(usize, 4), r.ok.index);
}

// --- run / runArena -----------------------------------------------------

test "Parser.run: takes an allocator and forwards it to ParseState" {
    // str doesn't allocate, but the run signature must thread the allocator
    // through ParseState.init for combinators that will (Phase 2 #29 many,
    // #34 sep-by, etc.). std.testing.allocator is leak-checked.
    const r = P.str("hi").run("hi there", std.testing.allocator);
    try std.testing.expect(r == .ok);
    try std.testing.expectEqualStrings("hi", r.ok.value);
    try std.testing.expectEqual(@as(usize, 2), r.ok.index);
}

test "Parser.runArena: ok path — caller deinit frees the arena" {
    var owned = try P.str("hello").runArena("hello world", std.testing.allocator);
    defer owned.deinit();
    try std.testing.expect(owned.result == .ok);
    try std.testing.expectEqualStrings("hello", owned.result.ok.value);
}

test "Parser.runArena: err path — caller deinit still frees the arena" {
    var owned = try P.str("hello").runArena("world", std.testing.allocator);
    defer owned.deinit();
    try std.testing.expect(owned.result == .err);
    try std.testing.expectEqualStrings("str", owned.result.err.parser);
}

test "formatParseErrorPretty: includes context and hint" {
    const input = "abc";
    const err: P.core.ParseError = .{
        .parser = "ident",
        .index = 2,
        .message = "name conflict",
        .expected = "x",
        .context = &.{ "outer", "inner" },
        .hint = "rename one",
    };
    const s = try P.core.formatParseErrorPretty(std.testing.allocator, input, err);
    defer std.testing.allocator.free(s);

    const expected =
        "ParseError [outer > inner] @ line 1, col 3 -> ident: name conflict\n" ++
        "  |\n" ++
        "1 | abc\n" ++
        "  |   ^ expected 'x'\n" ++
        "  = hint: rename one\n";
    try std.testing.expectEqualStrings(expected, s);
}
