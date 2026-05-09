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
