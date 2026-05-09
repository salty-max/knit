---
bump: minor
---

Add `whitespace()` and `whitespace1()` parsers under `parsers/whitespace/`. Both recognise the four ASCII whitespace bytes — space, tab, `\n`, `\r` — and return the borrowed byte slice. `whitespace()` is zero-or-more and always succeeds (empty match yields an empty slice with the cursor unchanged); `whitespace1()` is one-or-more and fails with `kind = .incomplete` on empty input or `.syntactic` on a non-whitespace cursor. Tabs and CRLF byte pairs are preserved verbatim. Vertical tab and form feed are deliberately excluded.
