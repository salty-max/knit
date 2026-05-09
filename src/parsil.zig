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

/// Replace a parser's failure identity with a custom name. See
/// `parsers/label.zig`.
pub const label = @import("parsers/label.zig").label;

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

/// Match a single ASCII decimal digit. See `parsers/digits/digit.zig`.
pub const digit = @import("parsers/digits/digit.zig").digit;

/// Match one-or-more ASCII decimal digits, returning the byte slice.
/// See `parsers/digits/digits.zig`.
pub const digits = @import("parsers/digits/digits.zig").digits;

/// Match a single ASCII letter (a-z, A-Z). See `parsers/letters/letter.zig`.
pub const letter = @import("parsers/letters/letter.zig").letter;

/// Match one-or-more ASCII letters, returning the byte slice. See
/// `parsers/letters/letters.zig`.
pub const letters = @import("parsers/letters/letters.zig").letters;

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

/// Run `left`, `p`, `right` in order; keep only `p`'s value.
/// Free-function complement to `Parser(T).between`. See
/// `parsers/between/between.zig`.
pub const between = @import("parsers/between/between.zig").between;
