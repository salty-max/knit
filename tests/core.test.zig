const std = @import("std");
const P = @import("parsil");

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
    try std.testing.expectEqual(@as(usize, 0), e.notes.len);
}

test "parseError: factory carries expected and actual" {
    const e = P.core.parseError("str", 0, "expected literal", .{
        .expected = "hello",
        .actual = "world",
    });
    try std.testing.expectEqualStrings("hello", e.expected.?);
    try std.testing.expectEqualStrings("world", e.actual.?);
}

test "parseError: factory carries hint and notes" {
    const notes_arr = [_]P.core.Note{
        .{ .message = "definition was here", .index = 10 },
        .{ .message = "consider renaming", .hint = "use snake_case" },
    };
    const e = P.core.parseError("ident", 5, "name conflict", .{
        .hint = "shadowing detected",
        .notes = &notes_arr,
    });
    try std.testing.expectEqualStrings("shadowing detected", e.hint.?);
    try std.testing.expectEqual(@as(usize, 2), e.notes.len);
    try std.testing.expectEqualStrings("definition was here", e.notes[0].message);
    try std.testing.expectEqual(@as(?usize, 10), e.notes[0].index);
    try std.testing.expectEqualStrings("use snake_case", e.notes[1].hint.?);
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

test "formatParseErrorPretty: includes context, hint, and notes" {
    const input = "abc";
    const notes_arr = [_]P.core.Note{
        .{ .message = "earlier site", .index = 0 },
    };
    const err: P.core.ParseError = .{
        .parser = "ident",
        .index = 2,
        .message = "name conflict",
        .expected = "x",
        .context = &.{ "outer", "inner" },
        .hint = "rename one",
        .notes = &notes_arr,
    };
    const s = try P.core.formatParseErrorPretty(std.testing.allocator, input, err);
    defer std.testing.allocator.free(s);

    const expected =
        "ParseError [outer > inner] @ line 1, col 3 -> ident: name conflict\n" ++
        "  |\n" ++
        "1 | abc\n" ++
        "  |   ^ expected 'x'\n" ++
        "  = hint: rename one\n" ++
        "  note: earlier site\n" ++
        "  |\n" ++
        "1 | abc\n" ++
        "  | ^\n";
    try std.testing.expectEqualStrings(expected, s);
}
