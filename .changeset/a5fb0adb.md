---
bump: major
---

Add `allocator` field to `ParseState` and require it in `Parser(T).run(input, allocator)`. Slice-producing combinators (`many`, `sepBy`, `sequenceOf`) and `ParseError.context` / `notes` now allocate via this allocator. New `Parser(T).runArena(input, child)` convenience wraps an `ArenaAllocator` lifecycle and returns an `ArenaResult` that owns the arena (caller calls `.deinit()`).
