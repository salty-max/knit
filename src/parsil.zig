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
