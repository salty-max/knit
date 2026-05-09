/// 1-indexed line and column derived from a byte offset into `input`.
pub const LineCol = struct { line: usize, col: usize };

/// Convert a byte offset into a 1-indexed `(line, col)` pair for
/// diagnostic display.
///
/// Recognised line-break sequences (each counts as exactly one line):
/// - `\n` (LF) — Unix / modern macOS
/// - `\r\n` (CRLF) — Windows
/// - `\r` alone — classic Mac OS (pre-2001)
///
/// `index` past the end of `input` clamps to the last byte. Tabs
/// occupy one column (consumers can post-process if their UI
/// renders wider tabs). **Columns are byte-counted, not
/// codepoint-counted** — a 2-byte UTF-8 codepoint like `'é'`
/// counts as 2 columns. UIs that show user-perceived character
/// columns should post-process via `std.unicode`.
///
/// Used at the consumer boundary — pretty-print parser errors
/// with `formatParseErrorPretty`, build LSP diagnostics, etc.
/// Cost is O(N) in the byte offset (no precomputed line index).
pub fn linecol(input: []const u8, index: usize) LineCol {
    var line: usize = 1;
    var col: usize = 1;
    var i: usize = 0;
    const upto = if (index > input.len) input.len else index;
    while (i < upto) {
        const b = input[i];
        if (b == '\n') {
            line += 1;
            col = 1;
            i += 1;
        } else if (b == '\r') {
            line += 1;
            col = 1;
            // Skip the LF if it's part of a CRLF pair so the
            // sequence counts as one line break, not two.
            if (i + 1 < upto and input[i + 1] == '\n') {
                i += 2;
            } else {
                i += 1;
            }
        } else {
            col += 1;
            i += 1;
        }
    }
    return .{ .line = line, .col = col };
}
