---
bump: minor
---

Add the bit-level numeric primitive family — `bit() / bitsBe(n) / bitsLe(n) / byteAligned()` — under `parsers/bit/`. Namespaced under `parsil.bit.` for symmetry with `parsil.binary.`. Extends `ParseState` with `bit_offset: u3` (0..7) for sub-byte tracking and a new `advanceBits(n)` method. The existing byte-level `advance(n)` method now resets `bit_offset` to 0 — a byte advance is byte-aligned by definition. Mixing bit + byte parsers is documented in CLAUDE.md: insert `byteAligned()` to reject unaligned state explicitly, otherwise the implicit reset silently discards partial-byte remainders.
