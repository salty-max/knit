# Parsil (Zig)

A tiny, composable parser-combinator toolkit for Zig. Small parsers compose into bigger ones via combinators (`sequenceOf`, `choice`, `many`, …); a clear minimal core (`ParseState`, `ParseResult`, `Parser(T)`, `ParseError`) underpins every primitive.

Parsil-zig is the Zig sibling of [parsil (TypeScript)](https://github.com/salty-max/parsil) — full API parity with parsil-TS 3.0.0 is the v1.0.0 milestone (work in progress under [v1.0.0](https://github.com/salty-max/parsil-zig/milestone/1)).

## Table of contents

- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Parsers (current shipping set)](#parsers)
- [Development](#development)
- [Compatibility](#compatibility)
- [Contributing](#contributing)

<a id="quick-start"></a>

<details open>
<summary><b>Quick Start</b></summary>

```bash
# Add parsil-zig to your project
zig fetch --save git+https://github.com/salty-max/parsil-zig
```

In `build.zig`:

```zig
const parsil = b.dependency("parsil_zig", .{
    .target = target,
    .optimize = optimize,
}).module("parsil");
exe.root_module.addImport("parsil", parsil);
```

In your code:

```zig
const std = @import("std");
const P = @import("parsil");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const r = P.str("hello").run("hello world", arena.allocator());
    if (r.isOk()) {
        const ok = r.ok; // value: []const u8, index: usize
        std.debug.print("matched '{s}' at offset {d}\n", .{ ok.value, ok.index });
    } else {
        const e = r.err; // parser, index, message, expected?, actual?, ...
        std.debug.print("parse failed at {d}: {s}\n", .{ e.index, e.message });
    }
}
```

The allocator is used for slice-producing combinators (`many`, `sepBy`, `sequenceOf`) and for `ParseError.context` / `notes`. An **arena** is the canonical choice — `arena.deinit()` frees everything in bulk. The `.runArena(input, child)` convenience does the wrap-and-deinit-on-result for you.

Requires Zig **0.16.0** or later.

</details>

<a id="core-concepts"></a>

<details>
<summary><b>Core Concepts</b></summary>

- **`ParseState`** — holds the input slice and current cursor; `.advance(n)` clamps to input length and is overflow-safe.
- **`ParseResult(T)`** — tagged union `.ok = { value: T, index: usize }` or `.err = ParseError`. `result.isOk()` is a type guard.
- **`Parser(T)`** — wraps a `*const fn (*ParseState) ParseResult(T)`. Run via `.run(input)` for the convenience entry point or `.parse(state)` when composing.
- **`ParseError`** — structured error: `{ parser, index, message, expected?, actual?, context? }`. The rich shape lands fully with the v1.0.0 milestone; the current minimal form is `{ index, msg, tag }`.

`Parser(T)` is a comptime-monomorphic function pointer — every parser captures its state via a comptime closure. Combinators that compose other parsers take their inputs as `comptime` parameters; runtime-assembled grammars use `recursive(thunk)`. There is no `*anyopaque` anywhere in the library.

</details>

<a id="parsers"></a>

<details>
<summary><b>Parsers (current shipping set)</b></summary>

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

### Digit primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `digit()` | `Parser(u21)` | Match a single ASCII decimal digit (`'0'..'9'`). |
| `digits()` | `Parser([]const u8)` | Match one-or-more ASCII decimal digits, returning the borrowed byte slice. |

### Letter primitives

| Symbol | Type | Description |
|--------|------|-------------|
| `letter()` | `Parser(u21)` | Match a single ASCII letter (`a-z` or `A-Z`). |
| `letters()` | `Parser([]const u8)` | Match one-or-more ASCII letters, returning the borrowed byte slice. |

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

### Alternative combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `choice(T, parsers)` | `Parser(T)` | First-success-wins across a homogeneous slice of `Parser(T)`; full backtrack between attempts; on total failure returns the inner error that reached the furthest cursor (ties: earliest in list). Compile-time error on empty slice. |

### Repetition combinators

| Symbol | Type | Description |
|--------|------|-------------|
| `many(T, p)` | `Parser([]T)` | Run `p` zero-or-more times; always succeeds. Stops on inner failure OR on no-progress (inner succeeded without consuming input — guards against infinite loops). |
| `manyOne(T, p)` | `Parser([]T)` | One-or-more; fails with `p`'s own error if zero matches. |
| `sepBy(sep, p)` | `Parser([]T)` | Zero-or-more `p` separated by `sep`; trailing `sep` is left in the input. |
| `sepByOne(sep, p)` | `Parser([]T)` | One-or-more, otherwise like `sepBy`; fails with `p`'s error on zero matches. |
| `sepEndBy(sep, p)` | `Parser([]T)` | Zero-or-more `p` separated by `sep`; trailing `sep` IS consumed. |
| `sepEndByOne(sep, p)` | `Parser([]T)` | One-or-more, otherwise like `sepEndBy`. |

### Error-context wrappers

| Symbol | Type | Description |
|--------|------|-------------|
| `inContext(T, label, p)` | `Parser(T)` | Push `label` onto `err.context` outer-first; success transparent. |
| `label(T, name, p)` | `Parser(T)` | Replace `err.parser` with `name`; other fields unchanged. |

### Running

| Symbol | Type | Description |
|--------|------|-------------|
| `Parser(T).run(input, allocator)` | `ParseResult(T)` | Run a parser against an input string. |
| `Parser(T).runArena(input, child)` | `!ArenaResult(T)` | Wrap an `ArenaAllocator` lifecycle; caller `.deinit()`s. |
| `Parser(T).parse(*ParseState)` | `ParseResult(T)` | Run a parser against an existing state (for composition). |

### Combinator methods (all `comptime self`)

| Method | Effect |
|--------|--------|
| `.map(U, fn)` | Transform success value |
| `.chain(U, fn)` | Sequence: `fn(T) Parser(U)`, run that next |
| `.errorMap(fn)` | Replace the error at consumer boundaries |
| `.skip(other)` | Run self then other, keep self's value |
| `.then(other)` | Run self then other, keep other's value |
| `.between(left, right)` | Sugar for `left.then(self).skip(right)` |
| `.lookahead()` | Non-consuming success |
| `.withSpan()` | Wrap result with byte offsets |
| `.spanMap(U, build)` | Build a caller-shaped node from value + span |

The Phase 2 set (`char`, `digits`, `letters`, `sequenceOf`, `choice`, `many`, `sepBy`, `between`, `possibly`, `lookAhead`, `peek`, `endOfInput`, `everythingUntil`, `recover`, `recursive`, `lexeme`, `lang`, `binary`, `bit`, …) lands progressively under [milestone v1.0.0](https://github.com/salty-max/parsil-zig/milestone/1).

</details>

<a id="development"></a>

<details>
<summary><b>Development</b></summary>

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

</details>

<a id="compatibility"></a>

<details>
<summary><b>Compatibility</b></summary>

- **Zig minimum**: 0.16.0 (pinned in `build.zig.zon`).
- **Cross-targets** compiled on every PR: `x86_64-linux`, `aarch64-macos`, `x86_64-windows`, `aarch64-windows`, `wasm32-wasi`.
- **Test runs** in CI: native Linux, every release mode (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall). The library is pure Zig with no OS-specific I/O — runtime tests on macOS/Windows are mostly redundant given the cross-target compile gate.

</details>

<a id="contributing"></a>

<details>
<summary><b>Contributing</b></summary>

- See [CONTRIBUTING.md](./CONTRIBUTING.md) for branching, commit format, the self-review loop, and the required toolchain.
- Bug reports and feature ideas → open a GitHub issue.
- New parsers and combinators → use the **parser** issue template and pick up an issue from the [v1.0.0 milestone](https://github.com/salty-max/parsil-zig/milestone/1).

</details>

---

License: [MIT](./LICENSE).
