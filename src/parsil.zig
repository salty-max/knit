/// Public API barrel. Consumers import this module via
/// `@import("parsil")` and use its re-exports — no deep paths into
/// `core` or `parsers/*` are part of the supported surface.
pub const core = @import("core");

/// Match a literal string. See `parsers/str/str.zig` for the
/// behaviour spec and error shapes.
pub const str = @import("parsers/str.zig").str;

/// Always fail with the supplied `ParseError`. See
/// `parsers/fail.zig`.
pub const fail = @import("parsers/fail.zig").fail;

/// Always succeed with the supplied value, no input consumed. See
/// `parsers/succeed.zig`.
pub const succeed = @import("parsers/succeed.zig").succeed;

/// Push a context label onto a parser's failure outer-first. See
/// `parsers/in-context.zig`.
pub const inContext = @import("parsers/in-context.zig").inContext;

/// Match a specific UTF-8 codepoint. See `parsers/char/char.zig`.
pub const char = @import("parsers/char/char.zig").char;

/// Match any single UTF-8 codepoint. See `parsers/char/any-char.zig`.
pub const anyChar = @import("parsers/char/any-char.zig").anyChar;

/// Match a codepoint that satisfies a predicate. See
/// `parsers/char/satisfy.zig`.
pub const satisfy = @import("parsers/char/satisfy.zig").satisfy;

/// Match a codepoint that appears in the supplied set. See
/// `parsers/char/one-of.zig`.
pub const oneOf = @import("parsers/char/one-of.zig").oneOf;

/// Match a codepoint that does NOT appear in the supplied set. See
/// `parsers/char/none-of.zig`.
pub const noneOf = @import("parsers/char/none-of.zig").noneOf;

/// Match any byte that does NOT start a successful parse of `p`.
/// See `parsers/char/any-char-except.zig`.
pub const anyCharExcept = @import("parsers/char/any-char-except.zig").anyCharExcept;

/// Match a single ASCII decimal digit. See `parsers/digits/digit.zig`.
pub const digit = @import("parsers/digits/digit.zig").digit;

/// Match one-or-more ASCII decimal digits, returning the byte slice.
/// See `parsers/digits/digits.zig`.
pub const digits = @import("parsers/digits/digits.zig").digits;

/// Match a single ASCII hex digit (`[0-9a-fA-F]`). See
/// `parsers/digits/hex-digit.zig`.
pub const hexDigit = @import("parsers/digits/hex-digit.zig").hexDigit;

/// Match a single ASCII octal digit (`[0-7]`). See
/// `parsers/digits/oct-digit.zig`.
pub const octDigit = @import("parsers/digits/oct-digit.zig").octDigit;

/// Match a single ASCII letter (a-z, A-Z). See `parsers/letters/letter.zig`.
pub const letter = @import("parsers/letters/letter.zig").letter;

/// Match one-or-more ASCII letters, returning the byte slice. See
/// `parsers/letters/letters.zig`.
pub const letters = @import("parsers/letters/letters.zig").letters;

/// Match a single ASCII alphanumeric (`[a-zA-Z0-9]`). See
/// `parsers/letters/alpha-num.zig`.
pub const alphaNum = @import("parsers/letters/alpha-num.zig").alphaNum;

/// Match a single ASCII uppercase letter (`[A-Z]`). See
/// `parsers/letters/upper.zig`.
pub const upper = @import("parsers/letters/upper.zig").upper;

/// Match a single ASCII lowercase letter (`[a-z]`). See
/// `parsers/letters/lower.zig`.
pub const lower = @import("parsers/letters/lower.zig").lower;

/// Match zero-or-more ASCII whitespace bytes (space, tab, `\n`,
/// `\r`), returning the byte slice. Always succeeds. See
/// `parsers/whitespace/whitespace.zig`.
pub const whitespace = @import("parsers/whitespace/whitespace.zig").whitespace;

/// Match one-or-more ASCII whitespace bytes, returning the byte
/// slice. Fails with `kind = .incomplete` on empty input,
/// `.syntactic` on a non-whitespace cursor. See
/// `parsers/whitespace/whitespace1.zig`.
pub const whitespace1 = @import("parsers/whitespace/whitespace1.zig").whitespace1;

/// Run a heterogeneous tuple of parsers in order; collect their
/// success values into a tuple of matching types. See
/// `parsers/sequence-of/sequence-of.zig`.
pub const sequenceOf = @import("parsers/sequence-of/sequence-of.zig").sequenceOf;

/// Result-tuple type function for `sequenceOf`. Public so consumers
/// can spell out the result type explicitly.
pub const TupleResult = @import("parsers/sequence-of/sequence-of.zig").TupleResult;

/// First-success-wins alternative across a homogeneous slice of
/// parsers, with full backtracking between attempts and
/// furthest-progress error on total failure. See
/// `parsers/choice/choice.zig`.
pub const choice = @import("parsers/choice/choice.zig").choice;

/// Match a parser zero-or-more times; always succeeds. See
/// `parsers/many/many.zig`.
pub const many = @import("parsers/many/many.zig").many;

/// Match a parser one-or-more times; fails if zero matches. See
/// `parsers/many/many-one.zig`.
pub const manyOne = @import("parsers/many/many-one.zig").manyOne;

/// Zero-or-more values separated by `sep`; trailing sep is left
/// in the input. See `parsers/sep-by/sep-by.zig`.
pub const sepBy = @import("parsers/sep-by/sep-by.zig").sepBy;

/// One-or-more values separated by `sep`; trailing sep is left in
/// the input. See `parsers/sep-by/sep-by-one.zig`.
pub const sepByOne = @import("parsers/sep-by/sep-by-one.zig").sepByOne;

/// Zero-or-more values separated by `sep`; trailing sep IS
/// consumed. See `parsers/sep-by/sep-end-by.zig`.
pub const sepEndBy = @import("parsers/sep-by/sep-end-by.zig").sepEndBy;

/// One-or-more values separated by `sep`; trailing sep IS
/// consumed. See `parsers/sep-by/sep-end-by-one.zig`.
pub const sepEndByOne = @import("parsers/sep-by/sep-end-by-one.zig").sepEndByOne;

/// Zero-or-more `(p sep)` pairs; every item requires a trailing
/// `sep` (no leniency for the last). See `parsers/sep-by/end-by.zig`.
pub const endBy = @import("parsers/sep-by/end-by.zig").endBy;

/// One-or-more `(p sep)` pairs; same trailing-sep-required
/// semantic. See `parsers/sep-by/end-by-one.zig`.
pub const endByOne = @import("parsers/sep-by/end-by-one.zig").endByOne;

/// Run `left`, `p`, `right` in order; keep only `p`'s value.
/// Free-function complement to `Parser(T).between`. See
/// `parsers/between/between.zig`.
pub const between = @import("parsers/between/between.zig").between;

/// Make a parser optional — failure becomes `ok` with `null`, no
/// consumption. Returns `Parser(?T)`. See
/// `parsers/possibly/possibly.zig`.
pub const possibly = @import("parsers/possibly/possibly.zig").possibly;

/// Run a parser without committing — non-consuming success, err
/// passes through with the cursor restored. Free-function
/// complement to `Parser(T).lookAhead`. See
/// `parsers/look-ahead/look-ahead.zig`.
pub const lookAhead = @import("parsers/look-ahead/look-ahead.zig").lookAhead;

/// Return the byte at the cursor without advancing; EOF → err.
/// See `parsers/peek/peek.zig`.
pub const peek = @import("parsers/peek/peek.zig").peek;

/// Assert the cursor is at end-of-input. Returns `Parser(void)`.
/// See `parsers/end-of-input/end-of-input.zig`.
pub const endOfInput = @import("parsers/end-of-input/end-of-input.zig").endOfInput;

/// Assert the cursor is at the start of input (index 0). Returns
/// `Parser(void)`. See `parsers/start-of-input/start-of-input.zig`.
pub const startOfInput = @import("parsers/start-of-input/start-of-input.zig").startOfInput;

/// Return the current byte offset (`state.index`) without
/// consuming. Useful inside `chain` / `apply` to capture
/// positions. See `parsers/position/index.zig`.
pub const index = @import("parsers/position/index.zig").index;

/// Match a parser exactly `n` times (comptime `n`). Returns
/// `Parser([]T)`. See `parsers/exactly/exactly.zig`.
pub const exactly = @import("parsers/exactly/exactly.zig").exactly;

/// Sequence: run `p`, hand its value to `fn_chain` to produce
/// the next parser, then run that. Free-function complement to
/// `Parser(T).chain`. See `parsers/chain/chain.zig`.
pub const chain = @import("parsers/chain/chain.zig").chain;

/// Consume bytes until `stopP` would succeed; return the
/// borrowed slice. See `parsers/everything-until/everything-until.zig`.
pub const everythingUntil = @import("parsers/everything-until/everything-until.zig").everythingUntil;

/// Codepoint-aware variant of `everythingUntil` — advances by full
/// UTF-8 codepoint width per iteration. See
/// `parsers/everything-until/every-char-until.zig`.
pub const everyCharUntil = @import("parsers/everything-until/every-char-until.zig").everyCharUntil;

/// Error recovery / synchronization: on `p` failure, scan forward
/// until any of `anchors` would match, then return `ok null` at
/// the recovery point. See `parsers/recover/recover-at.zig`.
pub const recoverAt = @import("parsers/recover/recover-at.zig").recoverAt;

/// Define a parser that references itself (or a parser that does)
/// via a lazy thunk — breaks construction-time cycles for
/// recursive grammars. See `parsers/recursive/recursive.zig`.
pub const recursive = @import("parsers/recursive/recursive.zig").recursive;

/// 1-indexed `(line, col)` byte-offset → position helper for
/// diagnostic display. Re-exported from `core` (which itself
/// re-exports from `util/linecol.zig`) — Zig 0.16 forbids the
/// same file from belonging to two modules, so we hop through
/// `core`'s already-imported reference.
pub const linecol = @import("core").linecol;

/// 1-indexed line+col pair returned by `linecol`. Re-exported
/// from `core` for the same module-membership reason.
pub const LineCol = @import("core").LineCol;

/// Token wrapper: run `p`, then consume trailing whitespace.
/// See `parsers/lexeme/tok.zig`.
pub const tok = @import("parsers/lexeme/tok.zig").tok;

/// Match an exact keyword literal followed by a non-identifier
/// byte, then consume trailing whitespace. See
/// `parsers/lexeme/keyword.zig`.
pub const keyword = @import("parsers/lexeme/keyword.zig").keyword;

/// Match a programming-language identifier (letter/underscore +
/// `[a-zA-Z0-9_]*`). See `parsers/lang/identifier.zig`.
pub const identifier = @import("parsers/lang/identifier.zig").identifier;

/// Match an unsigned integer literal in decimal / hex / octal /
/// binary; returns `i64`. See `parsers/lang/int-lit.zig`.
pub const intLit = @import("parsers/lang/int-lit.zig").intLit;

/// Match an unsigned decimal float literal (with optional
/// fraction and exponent); returns `f64`. See
/// `parsers/lang/float-lit.zig`.
pub const floatLit = @import("parsers/lang/float-lit.zig").floatLit;

/// Wrap an unsigned numeric parser to admit a leading `-` / `+`
/// sign and negate on `-`. See `parsers/lang/signed.zig`.
pub const signed = @import("parsers/lang/signed.zig").signed;

/// Match a double-quoted string literal with C-style escapes;
/// returns the decoded slice (allocated). See
/// `parsers/lang/string-lit.zig`.
pub const stringLit = @import("parsers/lang/string-lit.zig").stringLit;

/// Run `p`, call `fn_tap(state)` for side-effects, return `p`'s
/// result unchanged. The instrumentation seam. See
/// `parsers/util/tap.zig`.
pub const tap = @import("parsers/util/tap.zig").tap;

/// Run `p` and print a one-line trace of the result to stderr
/// prefixed with `label`. See `parsers/util/debug-log.zig`.
pub const debugLog = @import("parsers/util/debug-log.zig").debugLog;

/// Run `p`; on failure, replace the error's `message` with the
/// supplied `msg`. See `parsers/util/expect.zig`.
pub const expect = @import("parsers/util/expect.zig").expect;

/// Run `p`; on failure, replace the error's `parser` identity
/// with `name`. Pair with `expect` to also rewrite the message.
/// See `parsers/util/tag.zig`.
pub const tag = @import("parsers/util/tag.zig").tag;

/// Run a comptime tuple of parsers, apply `fn_apply` to the
/// result tuple. Sugar for `sequenceOf(parsers).map(U, fn_apply)`.
/// See `parsers/util/apply.zig`.
pub const apply = @import("parsers/util/apply.zig").apply;

/// Bit-level numeric primitives — `bit() / bitsBe(n) / bitsLe(n) /
/// byteAligned()`. Track sub-byte position via the `bit_offset`
/// field on `ParseState`. Mixing with byte parsers: the byte
/// `advance(n)` always resets `bit_offset` to 0 (byte-aligned by
/// definition); insert `byteAligned()` to reject the unaligned
/// state explicitly. See `parsers/bit/`.
pub const bit = struct {
    const single = @import("parsers/bit/bit.zig");
    const big = @import("parsers/bit/bits-be.zig");
    const little = @import("parsers/bit/bits-le.zig");
    const aligned = @import("parsers/bit/byte-aligned.zig");

    /// Read the next single bit (MSB-first within each byte).
    pub const bit = single.bit;
    /// Read the next `n` bits as `u64`, big-endian bit order.
    pub const bitsBe = big.bitsBe;
    /// Read the next `n` bits as `u64`, little-endian bit order.
    pub const bitsLe = little.bitsLe;
    /// Assert the cursor is byte-aligned (`bit_offset == 0`).
    pub const byteAligned = aligned.byteAligned;

    const zero_mod = @import("parsers/bit/zero.zig");
    const one_mod = @import("parsers/bit/one.zig");

    /// Assert the next bit is `0`; consume it.
    pub const zero = zero_mod.zero;
    /// Assert the next bit is `1`; consume it.
    pub const one = one_mod.one;

    const int_be = @import("parsers/bit/int-be.zig");
    const int_le = @import("parsers/bit/int-le.zig");

    /// Read `n` bits as a two's-complement signed `i64`, big-endian.
    pub const intBe = int_be.intBe;
    /// Read `n` bits as a two's-complement signed `i64`, little-endian.
    pub const intLe = int_le.intLe;
};

/// Fixed-width binary numeric primitives — `u8 / i8 / u16le /
/// u16be / ... / f64be`. Namespaced under `binary.` so the
/// parsers don't shadow Zig's primitive type names at the
/// `parsil.` top level. See `parsers/binary/`.
pub const binary = struct {
    const byte = @import("parsers/binary/byte.zig");
    const int16 = @import("parsers/binary/int16.zig");
    const int32 = @import("parsers/binary/int32.zig");
    const int64 = @import("parsers/binary/int64.zig");
    const float = @import("parsers/binary/float.zig");

    /// Byte-order tag (`.little` or `.big`) re-exported for callers that
    /// want to spell endianness out without importing `std`.
    pub const Endian = @import("parsers/binary/internal.zig").Endian;

    /// One byte as `u8`. EOF → `.incomplete`.
    pub const @"u8" = byte.u8;
    /// One byte as signed `i8`. EOF → `.incomplete`.
    pub const @"i8" = byte.i8;

    /// Two-byte little-endian `u16`. EOF → `.incomplete`.
    pub const u16le = int16.u16le;
    /// Two-byte big-endian `u16`. EOF → `.incomplete`.
    pub const u16be = int16.u16be;
    /// Two-byte little-endian signed `i16`. EOF → `.incomplete`.
    pub const i16le = int16.i16le;
    /// Two-byte big-endian signed `i16`. EOF → `.incomplete`.
    pub const i16be = int16.i16be;

    /// Four-byte little-endian `u32`. EOF → `.incomplete`.
    pub const u32le = int32.u32le;
    /// Four-byte big-endian `u32`. EOF → `.incomplete`.
    pub const u32be = int32.u32be;
    /// Four-byte little-endian signed `i32`. EOF → `.incomplete`.
    pub const i32le = int32.i32le;
    /// Four-byte big-endian signed `i32`. EOF → `.incomplete`.
    pub const i32be = int32.i32be;

    /// Eight-byte little-endian `u64`. EOF → `.incomplete`.
    pub const u64le = int64.u64le;
    /// Eight-byte big-endian `u64`. EOF → `.incomplete`.
    pub const u64be = int64.u64be;
    /// Eight-byte little-endian signed `i64`. EOF → `.incomplete`.
    pub const i64le = int64.i64le;
    /// Eight-byte big-endian signed `i64`. EOF → `.incomplete`.
    pub const i64be = int64.i64be;

    /// Four-byte little-endian IEEE-754 `f32`. EOF → `.incomplete`.
    pub const f32le = float.f32le;
    /// Four-byte big-endian IEEE-754 `f32`. EOF → `.incomplete`.
    pub const f32be = float.f32be;
    /// Eight-byte little-endian IEEE-754 `f64`. EOF → `.incomplete`.
    pub const f64le = float.f64le;
    /// Eight-byte big-endian IEEE-754 `f64`. EOF → `.incomplete`.
    pub const f64be = float.f64be;

    const bytes_mod = @import("parsers/binary/bytes.zig");

    /// Read exactly `n` raw bytes; return as a borrowed slice.
    /// EOF → `.incomplete`.
    pub const bytes = bytes_mod.bytes;
};
