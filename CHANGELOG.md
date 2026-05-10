# Changelog

All notable changes to knit are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
from v1.0.0 onward.

## v1.0.0 - 2026-05-10

First public release. Full parser-combinator toolkit for Zig — port of
[parsil (TypeScript)](https://www.npmjs.com/package/parsil) v3.0 with
Zig-specific value-adds (multi-error diagnostics, bit-level parser family).

### Naming & identity

- The library is **knit**. Package name in `build.zig.zon` is `.knit`,
  module is `@import("knit")`, public barrel is `src/knit.zig`.
- Repo home: `salty-max/knit` (formerly `salty-max/parsil-zig`; the old
  URL still resolves via GitHub redirect for existing consumers).

### Foundation

- `Parser(T)` — comptime-monomorphic function pointer (`*const fn (*ParseState) ParseResult(T)`).
  No `*anyopaque`, no `anyerror`, no type erasure. Combinators take
  parser inputs as `comptime` parameters; runtime-assembled grammars
  use `recursive(thunk)`.
- `ParseState` — input + cursor (`index: usize`) + sub-byte cursor
  (`bit_offset: u3`) + caller-owned allocator + optional `recovered_errs`
  diagnostic sink.
- `ParseResult(T)` — tagged union `.ok = { value: T, index: usize }`
  or `.err = ParseError`.
- `ParseError { parser, index, message, expected?, actual?, hint?,
  context, kind, severity }` — structured failures with `ParseErrorKind`
  classification (`incomplete`, `lexical`, `syntactic`, `semantic`,
  `internal`).
- `formatParseError` and `formatParseErrorPretty` for one-line and
  multi-line caret-style diagnostics. `linecol(input, index)` for
  byte-offset → 1-indexed `(line, col)` (LF + CRLF + classic-Mac CR).

### Parser primitives

- **char family** (UTF-8 aware, returning `Parser(u21)`):
  `char`, `anyChar`, `satisfy`, `oneOf`, `noneOf`, `anyCharExcept`.
- **digit family**: `digit`, `digits`, `hexDigit`, `octDigit`.
- **letter family**: `letter`, `letters`, `alphaNum`, `upper`, `lower`.
- **whitespace family**: `whitespace` (zero-or-more, always succeeds),
  `whitespace1` (one-or-more).
- **binary family** under `binary.` namespace: 18 fixed-width readers
  (`u8` / `i8` / `u16le` / `u16be` / … / `f64be`) plus `binary.bytes(n)`
  and `binary.Endian`.
- **bit family** under `bit.` namespace: `any` (single bit, value-agnostic),
  `bitsBe(n)` / `bitsLe(n)` (1..=64 bits as `u64`), `intBe(n)` / `intLe(n)`
  (signed two's-complement), `zero` / `one` (assertions), `byteAligned`.
  Tracked via `ParseState.bit_offset: u3`.
- **string / pseudo-primitives**: `str`, `fail`, `succeed`.

### Lang primitives

- `identifier` — letter/`_` then `[a-zA-Z0-9_]*`.
- `intLit` — decimal / `0x` hex / `0o` octal / `0b` binary, with
  identifier-byte boundary check.
- `floatLit` — decimal float with optional fraction / exponent.
- `signed(p)` — wrap a numeric inner parser to admit a leading `-` / `+`.
- `stringLit` — double-quoted string with `\n \t \r \\ \" \xHH` escapes.

### Combinators

- **Sequencing**: `sequenceOf` (heterogeneous tuple), `between`,
  `chain` (value-dependent), `chainl1` / `chainr1` (associative folds),
  `recursive` (lazy thunk for self-reference).
- **Alternative**: `choice` (first-success-wins, full-backtrack,
  furthest-progress error), `possibly` (optional `Parser(?T)`),
  `recoverAt` (synchronize on anchors, returns `null` on recovery).
- **Repetition**: `many` / `manyOne`, `exactly`, `sepBy` /
  `sepByOne` / `sepEndBy` / `sepEndByOne` / `endBy` / `endByOne`,
  `atLeast(n)` / `atMost(n)` / `repeatBetween(min, max)`. All include
  the no-progress break that prevents infinite loops on inner parsers
  that succeed without consuming input.
- **Lookahead**: `lookAhead`, `peek`, `endOfInput`, `startOfInput`,
  `index`.
- **Slicing**: `everythingUntil` (byte-level), `everyCharUntil`
  (codepoint-aware).
- **Lexeme**: `tok(p)`, `keyword(s)`.
- **Util / debugging**: `tap`, `debugLog`, `expect`, `tag`, `apply`,
  `inContext`.

### `Parser(T)` methods (all `comptime self`)

`.map`, `.chain`, `.errorMap`, `.skip`, `.then`, `.between`,
`.lookAhead`, `.withSpan`, `.spanMap`. Plus `.run(input, allocator)`,
`.runArena(input, child)`, `.runDiag(input, allocator)`, and
`.runDiagArena(input, child)` for the multi-error variant.

### Multi-error diagnostics

- `Diagnostic(T)` union returned by `runDiag` / `runDiagArena`. The
  parser stream collects every `recoverAt`-swallowed error (with
  `severity = .recovered`) alongside the value (or fatal error) — useful
  for compilers that want to surface every malformed construct in a
  single parse.
- The plain `.run` / `.runArena` paths leave the recovery sink unset, so
  recovered errors are dropped silently and existing single-error
  grammars pay zero perf cost.

### Allocator strategy

- Arena-per-parse: caller passes an allocator to `.run`; slice-producing
  combinators (`many`, `sepBy`, `sequenceOf`, …) and dynamic
  `ParseError.context` slices allocate via this allocator. The
  `.runArena(input, child)` convenience wraps an `ArenaAllocator`
  lifecycle and returns a result that owns the arena.
- Char-family parsers borrow `ParseError.actual` directly from
  `state.input` — zero allocation on err, even inside `choice` /
  `possibly` / `lookAhead` retries.

### Backtracking contract

- Every backtracker (`choice`, `Parser(T).lookAhead`, `possibly`,
  `recoverAt`'s anchor scan) saves and restores `index`, `bit_offset`,
  and `recovered_errs.items.len`. Adding a new mutable field to
  `ParseState` requires updating each call site in lockstep — see the
  CLAUDE.md *Backtracking state contract* section.

### Bug fixes

- Backtracking combinators didn't save/restore the `bit_offset` field —
  bit parsers inside any of them silently read from the wrong bit
  position. Fixed; regression-tested across all four combinators.
- Backtracking combinators didn't save/restore the `recovered_errs`
  list length — recovered errors from a discarded alternative leaked
  into the diagnostic sink. Fixed; regression-tested.

### Cross-target

- Builds for Linux x86_64, macOS aarch64, Windows x86_64 + aarch64, and
  `wasm32-wasi` on every CI run. Tests run in all four release modes
  (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall).
