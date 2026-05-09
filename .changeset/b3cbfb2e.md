---
bump: minor
---

Add the util family — `tap`, `debugLog`, `expect`, `tag`, `apply` — under `parsers/util/`. Debugging seams (`tap`, `debugLog`), error decoration (`expect` for message, `tag` for parser identity), and applied-sequence sugar (`apply` = `sequenceOf(parsers).map(U, fn)`). `tag` is the inferred-type complement to the existing `label(T, name, p)` — they overlap, slated for harmonization in a follow-up. `debugLog` is the only allowed user of `std.debug.print` in `src/`; the strict-lint script gets a per-file exemption for `parsers/util/debug-log.zig`.
