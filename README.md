# Parsil (Zig)

A tiny, composable parser toolkit for Zig. It provides a minimal core (`ParseState`, `ParseResult`, `Parser`) and small, focused parsers like `str(…)`. The goal is a clear foundation that’s easy to extend with combinators.

<details>
<summary>Quick Start</summary>

- Requires Zig `0.15.1`.
- Build and run tests:
  - `zig build test` (native)
  - `zig build test-all` (native + compile-only for extra targets)
- Use in code:

```zig
const P = @import("parsil");

const res = P.str("hello").run("hello world");
if (res.isOk()) {
    const ok = res.ok; // value: []const u8, index: usize
} else {
    const err = res.err; // index, msg, tag
}
```

</details>

<details>
<summary>Core Concepts</summary>

- `ParseState`: holds the input slice and current index; advancing clamps to the input length and is overflow-safe.
- `ParseResult(T)`: tagged union of `.ok` or `.err` with helpers like `isOk()`.
- `Parser(T)`: callable wrapper with `parse(*ParseState)` and `run([]const u8)`.

</details>

<details>
<summary>Parsers</summary>

- `str(target: []const u8) Parser([]const u8)`: matches a literal at the current index.
  - On success: returns the matched slice and advances the index.
  - On failure (wrong start): `ExpectedLiteral` at the starting index.
  - On failure (unexpected EOF): `UnexpectedEoF` at the first mismatched position.

</details>

<details>
<summary>Roadmap</summary>

- Core combinators: `map`, `then/seq`, `alt/or`, `many`, `optional`.
- Enriched errors with expected/actual and spans.
- More parsers: `char`, `satisfy`, numeric parsers, whitespace helpers.

</details>

<details>
<summary>Development</summary>

- Format: `zig fmt .`
- Test:
  - Native: `zig build test`
  - Cross targets (compile-only in addition to native run): `zig build test-all`

</details>

<details>
<summary>Compatibility</summary>

- Minimum Zig version: `0.15.1` (see `build.zig.zon`).
- Cross-targets compiled in build: Linux (x86_64), macOS (aarch64), Windows (x86_64, aarch64), and WASM (wasm32-wasi).
- CI runs on macOS and Linux and checks native tests plus cross-target compilation.

</details>

---
