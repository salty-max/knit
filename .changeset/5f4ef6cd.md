---
bump: minor
---

Add `endOfInput()` returning `Parser(void)` — assert the cursor is at end-of-input. Common pattern: `myParser.skip(endOfInput())` to require the entire input was consumed. On err, `actual` borrows the leftover prefix from `state.input` (capped at 16 bytes for readable diagnostics) — zero allocation, same lifetime guarantee as the rest of the borrow-from-input err shapes.
