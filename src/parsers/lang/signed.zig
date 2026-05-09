const core = @import("core");

/// Wrap an unsigned numeric parser to admit an optional leading
/// `-` or `+` sign. Negates the result on `-`; passes through on
/// `+` or no sign.
///
/// `T` (the inner parser's `Output`) must be a signed numeric
/// type — `i64`, `f64`, etc. Compile-time error on unsigned int
/// or non-numeric T (the negation `-x` would fail otherwise).
///
/// Example:
/// ```zig
/// const sint = comptime signed(intLit());
/// // sint.run("-42",  a) → ok = .{ .value = -42,  .index = 3 }
/// // sint.run("+42",  a) → ok = .{ .value =  42,  .index = 3 }
/// // sint.run("42",   a) → ok = .{ .value =  42,  .index = 2 }
///
/// const sfloat = comptime signed(floatLit());
/// // sfloat.run("-2.5e-3", a) → ok = .{ .value = -0.0025, .index = 7 }
/// ```
pub fn signed(comptime p: anytype) core.Parser(@TypeOf(p).Output) {
    const T = @TypeOf(p).Output;
    const ti = @typeInfo(T);
    comptime {
        if (ti != .int and ti != .float) {
            @compileError("signed: inner parser's Output must be a signed numeric type, got " ++ @typeName(T));
        }
        if (ti == .int and ti.int.signedness == .unsigned) {
            @compileError("signed: inner parser's Output must be SIGNED (negation requires it), got " ++ @typeName(T));
        }
    }
    const Thunk = struct {
        fn parse(state: *core.ParseState) core.ParseResult(T) {
            var negate = false;
            if (state.index < state.input.len) {
                const b = state.input[state.index];
                if (b == '-') {
                    negate = true;
                    state.advance(1);
                } else if (b == '+') {
                    state.advance(1);
                }
            }
            const r = p.parseFn(state);
            if (r == .err) return r;
            return core.ok(if (negate) -r.ok.value else r.ok.value, state.index);
        }
    };
    return .{ .parseFn = &Thunk.parse };
}
