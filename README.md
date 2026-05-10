# knit

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Zig 0.16+](https://img.shields.io/badge/Zig-0.16%2B-f7a41d.svg)](https://ziglang.org/download/)

A tiny, composable parser-combinator toolkit for Zig. Build complex grammars from small primitives (`char`, `digit`, `str`, `intLit`, …) via combinators (`sequenceOf`, `choice`, `many`, `chainl1`, …), with structured errors and opt-in multi-error recovery for grammar-author-friendly diagnostics.

> API design inspired by [parsil (TypeScript, npm)](https://www.npmjs.com/package/parsil) — the original library this is a Zig port of.

## Why knit

- **Zero dependencies** — pure Zig, no C, no FFI, no lockfile to chase.
- **Comptime-monomorphic** — `Parser(T)` is a plain function pointer with no `*anyopaque` and no `anyerror`. Types flow through your grammar all the way to the result.
- **Structured errors** — every primitive emits `ParseError { parser, index, message, expected?, actual?, context?, kind, severity }`; pair with `linecol(input, index)` for human-readable line/column diagnostics.
- **Multi-error recovery** — opt-in `runDiag` surfaces every malformed construct in one pass; useful for compilers that want to report N errors instead of stopping at the first. Zero perf cost when unused.
- **Cross-target** — Linux, macOS, Windows, `wasm32-wasi`, all built on every PR.

## Table of contents

- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Diagnostics & multi-error reporting](#diagnostics--multi-error-reporting)
- [API Reference](#api-reference)
  - [Primitive parsers](#primitive-parsers)
  - [Char primitives (UTF-8 aware)](#char-primitives-utf-8-aware)
  - [Digit primitives](#digit-primitives)
  - [Letter primitives](#letter-primitives)
  - [Whitespace primitives](#whitespace-primitives)
  - [Sequencing combinators](#sequencing-combinators)
  - [Alternative combinators](#alternative-combinators)
  - [Repetition combinators](#repetition-combinators)
  - [Error-context wrappers](#error-context-wrappers)
  - [Lexeme combinators](#lexeme-combinators)
  - [Util / debugging](#util--debugging)
  - [Lang primitives](#lang-primitives)
  - [Binary primitives](#binary-primitives)
  - [Bit primitives](#bit-primitives)
  - [Diagnostics helpers](#diagnostics-helpers)
  - [Running](#running)
  - [Combinator methods](#combinator-methods-all-comptime-self)
- [Development](#development)
- [Compatibility](#compatibility)
- [Contributing](#contributing)

## Quick Start

```bash
# Add knit to your project
zig fetch --save git+https://github.com/salty-max/knit
```

In `build.zig`:

```zig
const knit = b.dependency("knit", .{
    .target = target,
    .optimize = optimize,
}).module("knit");
exe.root_module.addImport("knit", knit);
```

In your code — a left-associative arithmetic expression parser, ~10 lines:

```zig
const std = @import("std");
const P = @import("knit");

const Ops = struct {
    fn add(a: i64, b: i64) i64 { return a + b; }
    fn sub(a: i64, b: i64) i64 { return a - b; }
    fn pick(c: u21) *const fn (i64, i64) i64 {
        return if (c == '+') &add else &sub;
    }
};

const op = P.oneOf(&.{ '+', '-' }).map(*const fn (i64, i64) i64, Ops.pick);
const expr = P.chainl1(i64, P.intLit(), op);

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const r = expr.run("1+2-3", arena.allocator());
    if (r == .ok) {
        std.debug.print("= {d}\n", .{r.ok.value}); // = 0  (left-assoc: (1+2)-3)
    } else {
        std.debug.print("error at {d}: {s}\n", .{ r.err.index, r.err.message });
    }
}
```

The allocator is used for slice-producing combinators (`many`, `sepBy`, `sequenceOf`) and for `ParseError.context`. An **arena** is the canonical choice — `arena.deinit()` frees everything in bulk. The `.runArena(input, child)` convenience wraps an arena lifecycle and returns a result that owns it.

Requires Zig **0.16.0** or later.

## Core Concepts

- **`ParseState`** — holds the input slice and current cursor; `.advance(n)` clamps to input length and is overflow-safe.
- **`ParseResult(T)`** — tagged union `.ok = { value: T, index: usize }` or `.err = ParseError`. `result.isOk()` is a type guard.
- **`Parser(T)`** — wraps a `*const fn (*ParseState) ParseResult(T)` plus chainable methods. Run via `.run(input, allocator)` (or `.runArena(input, child)` for arena lifecycle) at the top level, or `.parse(state)` when composing inside another parser.
- **`ParseError`** — structured error: `{ parser, index, message, expected?, actual?, context?, kind, severity }`. Format with `formatParseError(allocator, err)` for human-readable output, or attach a `(line, col)` via `linecol(input, err.index)`.

`Parser(T)` is a comptime-monomorphic function pointer — every parser captures its state via a comptime closure. Combinators that compose other parsers take their inputs as `comptime` parameters; runtime-assembled grammars use `recursive(thunk)`. There is no `*anyopaque` anywhere in the library.

## Diagnostics & multi-error reporting

By default, `parser.run(input, allocator)` returns the first error and stops. For grammars where you'd rather collect every malformed construct in one pass (asm, language compilers), wrap your top-level rule with `recoverAt` and run it via `runDiag` / `runDiagArena`:

```zig
const std = @import("std");
const P = @import("knit");

// statement = identifier `=` intLit `;`
const statement = P.sequenceOf(.{ P.identifier(), P.char('='), P.intLit(), P.char(';') });

// On failure inside a statement, scan forward to the next `;` and recover.
const program = P.recoverAt(statement, .{P.char(';')}).skip(P.possibly(P.char(';')));

pub fn main() !void {
    var owned = try P.many(program).runDiagArena("x=1;bad;y=2;", std.heap.page_allocator);
    defer owned.deinit();

    switch (owned.diag) {
        .ok => |ok| {
            std.debug.print("parsed {d} statements; {d} recovered errors:\n", .{ ok.value.len, ok.recovered.len });
            for (ok.recovered) |err| std.debug.print("  - at {d}: {s}\n", .{ err.index, err.message });
        },
        .err => |e| std.debug.print("fatal: {s}\n", .{e.primary.message}),
    }
}
```

Output:

```
parsed 3 statements; 1 recovered errors:
  - at 7: unexpected codepoint
```

The plain `.run` / `.runArena` paths leave the recovery sink unset — recovered errors are dropped silently, so existing single-error grammars pay zero perf cost.

## API Reference

### Primitive parsers

| Symbol | Type | Description |
|--------|------|-------------|
| `str(target)` | `Parser([]const u8)` | Match an exact literal at the cursor. |
| `fail(error)` | `Parser(noreturn)` | Always fail with the supplied `ParseError`. |
| `succeed(T, value)` | `Parser(T)` | Always succeed with the supplied value, no input consumed. |

### Char primitives (UTF-8 aware)

| Symbol | Type | Description |
|--------|------|-------------|
| `char(c)` | `Parser(u21)` | Match exact codepoint, advance by its byte width. |
| `anyChar()` | `Parser(u21)` | Match any single codepoint. |
| `satisfy(predicate, name)` | `Parser(u21)` | Match codepoint passing `predicate`; `name` is the parser identity. |
| `oneOf(set)` | `Parser(u21)` | Match a codepoint in `[]const u21` set. |
| `noneOf(set)` | `Parser(u21)` | Match a codepoint NOT in the set. |
| `anyCharExcept(p)` | `Parser(u8)` | Consume one byte unless `p` would match at the cursor; useful for "consume until sentinel" patterns. |

### Digit primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `digit()` | `Parser(u21)` | Match a single ASCII decimal digit (`'0'..'9'`). |
| `digits()` | `Parser([]const u8)` | Match one-or-more ASCII decimal digits, returning the borrowed byte slice. |
| `hexDigit()` | `Parser(u21)` | Match a single ASCII hex digit (`[0-9a-fA-F]`). |
| `octDigit()` | `Parser(u21)` | Match a single ASCII octal digit (`[0-7]`). |

### Letter primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `letter()` | `Parser(u21)` | Match a single ASCII letter (`a-z` or `A-Z`). |
| `letters()` | `Parser([]const u8)` | Match one-or-more ASCII letters, returning the borrowed byte slice. |
| `alphaNum()` | `Parser(u21)` | Match a single ASCII alphanumeric (`[a-zA-Z0-9]`). |
| `upper()` | `Parser(u21)` | Match a single ASCII uppercase letter (`[A-Z]`). |
| `lower()` | `Parser(u21)` | Match a single ASCII lowercase letter (`[a-z]`). |

### Whitespace primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `whitespace()` | `Parser([]const u8)` | Match zero-or-more whitespace bytes (` `, `\t`, `\n`, `\r`); always succeeds, returns the borrowed byte slice (possibly empty). |
| `whitespace1()` | `Parser([]const u8)` | Match one-or-more whitespace bytes; fails with `.incomplete` on EOF, `.syntactic` on a non-whitespace cursor. |

### Sequencing combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `sequenceOf(parsers)` | `Parser(TupleResult(@TypeOf(parsers)))` | Run a comptime tuple of parsers in order; collect success values into a heterogeneous tuple. Cursor stops at the failing parser on error. |
| `TupleResult(ParsersType)` | `type` | Result-tuple type function for `sequenceOf` — `struct { Parser(T0), …, Parser(Tn) }` → `struct { T0, …, Tn }`. |
| `between(left, p, right)` | `Parser(T)` | Run `left`, `p`, `right`; keep only `p`'s value. Free-function complement to `Parser(T).between`. |
| `lookAhead(p)` | `Parser(T)` | Run `p` non-consuming; success keeps the value but restores the cursor; failure passes through with cursor also restored. Free-function complement to `Parser(T).lookAhead`. |
| `chain(p, U, fn)` | `Parser(U)` | Sequence with value dependency: run `p`, pass its value to `fn` to produce the next parser, then run that. Free-function complement to `Parser(T).chain`. |
| `chainl1(T, operand, op)` | `Parser(T)` | Left-associative fold over `operand (op operand)*`. `op` produces a `*const fn(T, T) T`. Single-operand input → that operand. |
| `chainr1(T, operand, op)` | `Parser(T)` | Right-associative fold; same shape as `chainl1`. Use over `chainl1` when the operator is right-assoc (e.g. `^`, `->`). |
| `recursive(T, thunk)` | `Parser(T)` | Define a parser that references itself via a lazy `thunk: fn () Parser(T)`. Breaks construction-time cycles for recursive grammars. No left recursion. |
| `everythingUntil(stopP)` | `Parser([]const u8)` | Consume bytes until `stopP` would succeed; return the borrowed slice. Cursor lands at the start of `stopP`'s match — `stopP` itself isn't consumed. EOF without match → err. |
| `everyCharUntil(stopP)` | `Parser([]const u8)` | Codepoint-aware `everythingUntil` — advances by UTF-8 codepoint width per iteration. Invalid / truncated UTF-8 → err. |
| `peek()` | `Parser(u8)` | Return the byte at the cursor without advancing. Byte-level (no UTF-8 decode). EOF → `.incomplete`. |
| `endOfInput()` | `Parser(void)` | Assert the cursor is at end-of-input. Err carries `actual` borrowed from the leftover prefix (capped at 16 bytes). |
| `startOfInput()` | `Parser(void)` | Assert the cursor is at the start of input (index 0). Symmetric to `endOfInput`. |
| `index()` | `Parser(usize)` | Return the current byte offset without consuming. Useful inside `chain` / `apply` to capture positions without `withSpan`. |

### Alternative combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `choice(T, parsers)` | `Parser(T)` | First-success-wins across a homogeneous slice of `Parser(T)`; full backtrack between attempts; on total failure returns the inner error that reached the furthest cursor (ties: earliest in list). Compile-time error on empty slice. |
| `possibly(p)` | `Parser(?T)` | Make `p` optional. Success wraps in `?T`; failure rolls back the cursor and returns `ok null`. Always succeeds. |
| `recoverAt(p, anchors)` | `Parser(?T)` | On `p` failure, scan forward until any of the `Parser(void)` `anchors` matches; return `ok null` with cursor at the recovery point (anchor not consumed). Hit EOF without matching → propagate `p`'s err. Compile-time error on empty anchors. |

### Repetition combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `many(p)` | `Parser([]T)` | Run `p` zero-or-more times; always succeeds. Stops on inner failure OR on no-progress (inner succeeded without consuming input — guards against infinite loops). |
| `manyOne(p)` | `Parser([]T)` | One-or-more; fails with `p`'s own error if zero matches. |
| `exactly(n, p)` | `Parser([]T)` | Match `p` exactly `n` times (comptime `n`). Pre-allocates the result slice. |
| `sepBy(sep, p)` | `Parser([]T)` | Zero-or-more `p` separated by `sep`; trailing `sep` is left in the input. |
| `sepByOne(sep, p)` | `Parser([]T)` | One-or-more, otherwise like `sepBy`; fails with `p`'s error on zero matches. |
| `sepEndBy(sep, p)` | `Parser([]T)` | Zero-or-more `p` separated by `sep`; trailing `sep` IS consumed. |
| `sepEndByOne(sep, p)` | `Parser([]T)` | One-or-more, otherwise like `sepEndBy`. |
| `endBy(sep, p)` | `Parser([]T)` | Zero-or-more `(p sep)` pairs; every match requires a trailing `sep` (unlike `sepBy` / `sepEndBy`, no leniency for the last). |
| `endByOne(sep, p)` | `Parser([]T)` | One-or-more, otherwise like `endBy`. |
| `atLeast(n, p)` | `Parser([]T)` | Match `p` at least `n` times (no upper bound); fails if fewer. Compile-time error if `n == 0`. |
| `atMost(n, p)` | `Parser([]T)` | Match `p` at most `n` times; always succeeds. |
| `repeatBetween(min, max, p)` | `Parser([]T)` | Match between `min` and `max` times (inclusive, comptime bounds). |

### Error-context wrappers

| Symbol | Type | Description |
|--------|------|-------------|
| `inContext(T, label, p)` | `Parser(T)` | Push `label` onto `err.context` outer-first; success transparent. |

### Lexeme combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `tok(p)` | `Parser(T)` | Run `p`, then consume trailing whitespace. Returns `p`'s value with `.Output` preserved. |
| `keyword(s)` | `Parser([]const u8)` | Match exact literal `s` followed by a non-identifier byte (or EOF), then consume trailing whitespace. Identifier-continuation chars are `[a-zA-Z0-9_]`. Compile-time error on empty `s`. |

### Util / debugging

| Symbol | Type | Description |
|--------|------|-------------|
| `tap(p, fn)` | `Parser(T)` | Run `p`, call `fn(*const ParseState)` for side-effects, return `p`'s result. Instrumentation seam. |
| `debugLog(p, label)` | `Parser(T)` | Run `p`, print one-line trace to stderr prefixed with `label`. Allowlisted use of `std.debug.print`. |
| `expect(p, msg)` | `Parser(T)` | On err, replace `err.message` with `msg` (other fields unchanged). |
| `tag(p, name)` | `Parser(T)` | On err, replace `err.parser` with a domain-specific identity. Pair with `expect` to also rewrite the message. |
| `apply(parsers, U, fn)` | `Parser(U)` | Sugar for `sequenceOf(parsers).map(U, fn)` — runs the comptime parser tuple, applies `fn` to the result tuple. |

### Lang primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `identifier()` | `Parser([]const u8)` | Letter or `_`, then `[a-zA-Z0-9_]*`; returns the borrowed slice. |
| `intLit()` | `Parser(i64)` | Unsigned integer literal in decimal / `0x` hex / `0o` octal / `0b` binary. Identifier-byte boundary check. |
| `floatLit()` | `Parser(f64)` | Unsigned decimal float with optional fraction and/or exponent. Bare integers fall through to `intLit`'s shape. |
| `signed(p)` | `Parser(T)` | Wrap a signed-numeric inner parser to admit a leading `-` / `+`. Compile-time error on unsigned/non-numeric `T`. |
| `stringLit()` | `Parser([]const u8)` | Double-quoted string with `\n \t \r \\ \" \xHH` escapes; returns the decoded slice (**allocated** — needs `runArena`). |

### Binary primitives

Fixed-width numeric reads, namespaced under `binary.` so the parser names don't shadow Zig's primitive type names at the top level.

| Symbol | Type | Description |
|--------|------|-------------|
| `binary.u8()` / `binary.i8()` | `Parser(u8)` / `Parser(i8)` | One byte (un/signed). |
| `binary.u16le()` / `binary.u16be()` | `Parser(u16)` | Two-byte unsigned, little/big-endian. |
| `binary.i16le()` / `binary.i16be()` | `Parser(i16)` | Two-byte signed. |
| `binary.u32le()` / `binary.u32be()` | `Parser(u32)` | Four-byte unsigned. |
| `binary.i32le()` / `binary.i32be()` | `Parser(i32)` | Four-byte signed. |
| `binary.u64le()` / `binary.u64be()` | `Parser(u64)` | Eight-byte unsigned. |
| `binary.i64le()` / `binary.i64be()` | `Parser(i64)` | Eight-byte signed. |
| `binary.f32le()` / `binary.f32be()` | `Parser(f32)` | IEEE-754 binary32. |
| `binary.f64le()` / `binary.f64be()` | `Parser(f64)` | IEEE-754 binary64. |
| `binary.bytes(n)` | `Parser([]const u8)` | Read exactly `n` raw bytes; borrowed slice. |
| `binary.Endian` | `enum { little, big }` | Byte-order tag re-exported from internal. |

EOF before the required width always yields `kind = .incomplete`.

### Bit primitives

Sub-byte reads, namespaced under `bit.`. Track sub-byte position via `state.bit_offset: u3`. Mixing with byte parsers: a byte `advance(n)` always resets `bit_offset` to 0 — insert `bit.byteAligned()` to reject the unaligned state explicitly.

| Symbol | Type | Description |
|--------|------|-------------|
| `bit.any()` | `Parser(u1)` | Next single bit (MSB-first within each byte), value-agnostic. Pair with `bit.zero()` / `bit.one()` for assertions. |
| `bit.bitsBe(n)` | `Parser(u64)` | Next `n` bits (1..=64), big-endian bit order — first bit becomes MSB. |
| `bit.bitsLe(n)` | `Parser(u64)` | Next `n` bits, little-endian bit order — first bit becomes LSB; bytes still in input order. |
| `bit.byteAligned()` | `Parser(void)` | Assert `bit_offset == 0`; err otherwise. |
| `bit.zero()` | `Parser(void)` | Assert next bit is `0`; consume it. |
| `bit.one()` | `Parser(void)` | Assert next bit is `1`; consume it. |

### Diagnostics helpers

| Symbol | Type | Description |
|--------|------|-------------|
| `linecol(input, index)` | `LineCol` | Convert a byte offset to 1-indexed `(line, col)`. Recognises LF, CRLF, and CR as line breaks — works regardless of the OS that produced the input. Columns are byte-counted (UI-side post-processing required for codepoint-counted columns). |
| `LineCol` | `struct { line: usize, col: usize }` | The 1-indexed line/col pair returned by `linecol`. |

### Running

| Symbol | Type | Description |
|--------|------|-------------|
| `Parser(T).run(input, allocator)` | `ParseResult(T)` | Run a parser against an input string. |
| `Parser(T).runArena(input, child)` | `!ArenaResult(T)` | Wrap an `ArenaAllocator` lifecycle; caller `.deinit()`s. |
| `Parser(T).parse(*ParseState)` | `ParseResult(T)` | Run a parser against an existing state (for composition). |
| `Parser(T).runDiag(input, allocator)` | `Diagnostic(T)` | Multi-error variant: collects every `recoverAt`-recovered err alongside the value (or fatal err). |
| `Parser(T).runDiagArena(input, child)` | `!DiagnosticArenaResult(T)` | Arena-backed variant of `runDiag`. |

### Combinator methods (all `comptime self`)

| Method | Effect |
|--------|--------|
| `.map(U, fn)` | Transform success value |
| `.chain(U, fn)` | Sequence: `fn(T) Parser(U)`, run that next |
| `.errorMap(fn)` | Replace the error at consumer boundaries |
| `.skip(other)` | Run self then other, keep self's value |
| `.then(other)` | Run self then other, keep other's value |
| `.between(left, right)` | Sugar for `left.then(self).skip(right)` |
| `.lookAhead()` | Non-consuming success |
| `.withSpan()` | Wrap result with byte offsets |
| `.spanMap(U, build)` | Build a caller-shaped node from value + span |

Coverage spans the core, char, digit, letter, whitespace, sequence, choice, many / sepBy / endBy / repeatBetween, lookahead / recovery, lexeme, lang, binary, and bit families. See the [CHANGELOG](./CHANGELOG.md) for per-version detail.

## Development

Three external tools, all single-binary installs:

```bash
# macOS (Homebrew)
brew install zig lefthook convco

# Linux (apt or your distro's equivalent)
# zig:      see https://ziglang.org/download/
# lefthook: https://github.com/evilmartians/lefthook#install
# convco:   cargo install convco  (or download release binary)
```

After cloning:

```bash
lefthook install                  # wires git hooks
zig build --help                  # discover every dev command
zig build ci                      # what CI runs: lint + 4 release modes + cross-target compile
```

Common `zig build` steps:

| Step | Purpose |
|------|---------|
| `zig build` | Build the library |
| `zig build test` | Run native tests (Debug) |
| `zig build test-modes` | Run tests in Debug + ReleaseSafe + ReleaseFast + ReleaseSmall |
| `zig build test-all` | Cross-target compile on Linux, macOS, Windows, wasm32-wasi |
| `zig build fmt` / `fmt-check` | Format / format-check |
| `zig build lint` | Format + every static check |
| `zig build ci` | Local equivalent of CI (lint + test-modes + test-all) |
| `zig build changeset` | Scaffold a new changeset interactively |

See [CONTRIBUTING.md](./CONTRIBUTING.md) for branching, commit conventions, and the self-review loop.

## Compatibility

- **Zig minimum**: 0.16.0 (pinned in `build.zig.zon`).
- **Zero runtime dependencies** — pure Zig, no C deps, no FFI. Your `build.zig.zon` only adds `knit`.
- **Cross-targets** compiled on every PR: `x86_64-linux`, `aarch64-macos`, `x86_64-windows`, `aarch64-windows`, `wasm32-wasi`.
- **Test runs** in CI: native Linux, every release mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall). The library is pure Zig with no OS-specific I/O — runtime tests on macOS/Windows are mostly redundant given the cross-target compile gate.
- **SemVer** from v1.0.0 onward. Breaking changes bump the major; new parsers/combinators bump the minor; bug fixes bump the patch. Each release ships with a `CHANGELOG.md` section enumerating the user-visible deltas.

## Contributing

- See [CONTRIBUTING.md](./CONTRIBUTING.md) for branching, commit format, the self-review loop, and the required toolchain.
- Bug reports and feature ideas → open a GitHub issue.
- New parsers and combinators → use the **parser** issue template; tag-team welcome on open issues.

---

License: [MIT](./LICENSE).
