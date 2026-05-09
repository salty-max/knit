const std = @import("std");
const core = @import("core");

/// Build the result tuple type for `sequenceOf` from a parsers tuple
/// type. Given `struct { Parser(T0), Parser(T1), ..., Parser(Tn) }`,
/// returns the anonymous tuple `struct { T0, T1, ..., Tn }`.
///
/// Public so consumers can spell out the result type when they need
/// to (function signatures, type aliases, generic helpers). Most
/// callers won't touch it directly — `sequenceOf(...)` infers it.
pub fn TupleResult(comptime ParsersType: type) type {
    const fields = @typeInfo(ParsersType).@"struct".fields;
    var types: [fields.len]type = undefined;
    for (fields, 0..) |f, i| types[i] = f.type.Output;
    return @Tuple(&types);
}

/// Run a heterogeneous sequence of parsers and collect the success
/// values into a tuple. Each parser keeps its own value type — the
/// returned `Parser(T)` carries `T = struct { T0, T1, ..., Tn }`
/// where each `Ti` is the corresponding parser's `.Output`.
///
/// Backtracking: if any inner parser fails, `sequenceOf` returns
/// that error unchanged with the cursor left at the failing
/// position. To try alternative sequences, wrap each in `choice`
/// (which handles its own state save/restore).
///
/// Example:
/// ```zig
/// const greeting = comptime sequenceOf(.{
///     str("hello"),
///     whitespace1(),
///     letters(),
/// });
/// // greeting.run("hello world", alloc)
/// //   → ok = .{ .value = .{ "hello", " ", "world" }, .index = 11 }
/// ```
pub fn sequenceOf(comptime parsers: anytype) core.Parser(TupleResult(@TypeOf(parsers))) {
    const Result = TupleResult(@TypeOf(parsers));
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(Result) {
            var result: Result = undefined;
            inline for (parsers, 0..) |p, i| {
                const r = p.parseFn(state);
                if (r == .err) return .{ .err = r.err };
                result[i] = r.ok.value;
            }
            return core.ok(result, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
