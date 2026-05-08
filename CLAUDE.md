# Parsil Zig — Claude Guidelines

## Project Overview

Parsil Zig is a small, dependency-free parser-combinator library for Zig. Tiny parsers compose into bigger ones via combinators (`sequenceOf`, `choice`, `many`, `recursive`, …) and run on textual input (UTF-8 strings) or binary input (byte slices). Spans are first-class via `withSpan` / `spanMap`.

Parsil Zig is the parser foundation for downstream Gero projects: the Gero VM (Zig rewrite), the asm compiler, the future Gero language, and the gtx-16 native runtime. Every change here can land in those consumers — favor stability, clear semantics, and well-documented edge cases over feature breadth.

What parsil-zig **is**:

- A combinator kernel (`Parser(T)` + a set of primitive parsers and combinators under `src/parsers/`)
- Pure Zig, zero runtime dependencies
- Builds for Linux, macOS, Windows, and `wasm32-wasi`
- The Zig sibling of [parsil](https://github.com/salty-max/parsil) (TypeScript), API-aligned with parsil-TS 3.0.0 (full parity is the v1.0.0 milestone)

What parsil-zig **is not**:

- A grammar generator (PEG.js, nearley) — there is no grammar file format
- A lexer/tokenizer toolkit — bytes/codepoints are the granularity by default
- An AST utility library — call sites build their own AST shapes

## Tech Stack

- **Zig 0.16.0** minimum (pinned in `build.zig.zon`'s `minimum_zig_version`)
- **Zero runtime deps** — pure Zig, no C dependencies, no FFI
- **Build, test, lint, release tooling**: `build.zig` is the task runner. Every dev command is a `zig build <step>` (run `zig build --help` to list them). No Justfile, no Make, no shell-script wrapper at the root.
- **Format**: `zig fmt` (driven via `zig build fmt` / `zig build fmt-check`)
- **Git hooks**: [lefthook](https://github.com/evilmartians/lefthook) — single binary, language-agnostic, no Node
- **Conventional commits**: [convco](https://github.com/convco/convco) — Rust binary, validates messages against `.convco.toml`
- **Changesets**: manual `.changeset/*.md` format with shell scripts under `scripts/` (no Node dependency)

There is **no** Node, no Bun, no npm, no Cargo (other than installing the two binaries above) anywhere in this project's dev loop.

Don't add a Node-shaped tool to solve a Zig-shaped problem. `build.zig` already runs arbitrary commands via `b.addSystemCommand` — reach for that before reaching for a wrapper.

## Source Layout

```
src/
├── core.zig                # Parser(T), ParseState, ParseResult, ParseError
├── parsil.zig              # Public barrel (re-exports core + parsers)
├── parsers/
│   ├── <name>/
│   │   ├── <name>.zig      # Implementation
│   │   ├── <variant>.zig   # Variant when applicable (e.g. many-one.zig under many/)
│   │   └── README.zig      # Optional in-source notes; usually unnecessary
│   └── …
└── util/
    └── <topic>.zig

tests/
├── util.zig                # assertOk / assertErr / shared test helpers
├── core/
│   └── <symbol>.test.zig   # one spec per public core symbol
└── parsers/
    └── <name>/<file>.test.zig  # mirrors src/parsers/<name>/<file>.zig

scripts/                    # bash helpers invoked from build.zig + lefthook
.changeset/                 # *.md changeset files, one per user-visible PR
.github/                    # workflows + issue/PR templates
build.zig                   # task runner: every dev command is `zig build <step>`
build.zig.zon
lefthook.yml
.convco.toml
CLAUDE.md                   # this file
README.md
CONTRIBUTING.md
CHANGELOG.md
LICENSE
```

**Mirror rule**: every `src/parsers/<name>/<file>.zig` has a matching `tests/parsers/<name>/<file>.test.zig`. `scripts/check-mirror.sh` enforces this in CI. Adding a new parser without a matching spec fails CI.

## Parser Design Principles

### Small, composable units

Each parser does **one** thing. If a combinator's body is more than ~40 lines or branches on more than a couple of state shapes, split it. The whole point of the library is that complex grammars emerge from composition — don't bake special cases into primitives.

### No hidden state

A parser is a pure function `state -> state`. Never close over module-level mutable state, never read from globals, never use `std.time.nanoTimestamp()` or `std.crypto.random` inside a parser body. The same input must always produce the same output. This is what makes `withSpan`, `lookahead`, and backtracking work.

### Carry types through

Every public parser is `Parser(T)` for a specific `T`. Use comptime to thread types — never erase to `*anyopaque` in a public signature. Heterogeneous parser arrays (`choice`, `sequenceOf`) accept comptime tuples or `[]const Parser(T)` slices with a shared `T`; `fail(error)` returns `Parser(noreturn)` because it can never produce a result.

**No `*anyopaque` — anywhere.** `Parser(T)` is just a comptime-monomorphic function pointer:

```zig
pub fn Parser(comptime T: type) type {
    return struct {
        parseFn: *const fn (state: *ParseState) ParseResult(T),
        // ...
    };
}
```

Every parser's captured state is comptime — `str("foo")` and `str("bar")` instantiate distinct anonymous-struct closures whose function pointers happen to share the same `Parser([]const u8)` signature. No type-erased context is needed.

Consequence: combinators that compose other parsers (`map`, `chain`, `choice`, `sequenceOf`, `between`, …) take their inputs as `comptime` parameters. Method-chaining survives only for transformations whose `Parser(T)` is comptime-known. For runtime-assembled grammars, use `recursive(thunk)` (lazy) instead of dynamic composition.

**No `anyerror`.** Use explicit error sets (`error{Foo, Bar}!T`) so callers can exhaustively handle failures. `scripts/check-strict.sh` greps for `anyerror` in `src/` and fails CI if any appear without an allowlist comment.

**Justified casts.** `@as`, `@ptrCast`, `@alignCast`, `@bitCast` require a one-line `// @as: <reason>` or `// safety: <reason>` comment directly above the call. The lint script enforces this.

### Source positions are not optional

Every grammar that targets diagnostics needs spans. Don't re-implement position tracking in user code — use `withSpan()` / `spanMap()` on the parser whose output you want located. Adding a new combinator? Make sure its result is reachable through `spanMap` (return values, not internal indices).

### Allocator strategy: arena-per-parse

Every `.run(input, allocator)` takes an allocator from the caller. The convention is **arena-per-parse**: caller wraps a `std.heap.ArenaAllocator`, runs the parser, reads the result, then `arena.deinit()` frees all parser-allocated state in bulk.

All slice-producing combinators (`many`, `sepBy`, `sequenceOf`, etc.) and the error `context` slice allocate via this allocator. Callers must not retain slices past `arena.deinit()`.

The convenience method `Parser(T).runArena(input)` creates the arena, runs, and returns a wrapper that owns the arena (caller calls `.deinit()`).

## Error Handling

### Structured `ParseError`

Primitive parsers emit a `ParseError` struct, not a string:

```zig
pub const ParseError = struct {
    parser: []const u8,            // 'char', 'str', 'keyword', ...
    index: usize,
    message: []const u8,
    expected: ?[]const u8 = null,
    actual:   ?[]const u8 = null,
    context:  []const []const u8 = &.{},  // outer-first labels from inContext
};
```

When emitting a failure inside a primitive, build the error with the `parseError(parser, index, message, .{ ... })` factory and route it through `updateError`:

```zig
return updateError(state, parseError(
    "char",
    state.index,
    "expected codepoint",
    .{ .expected = "'a'", .actual = next_codepoint_str },
));
```

The string format `ParseError [outer > inner] @ index N -> <parser>: <message>` lives in `formatParseError(allocator, error) ![]u8`. Don't hand-build that string in primitives.

### Two layers

1. **Library errors**: every primitive emits `ParseError` via `parseError(...)`. The `parser` field is the machine-readable identity; `message` is the user-readable description. Don't include `ParseError @ index N -> X:` prefix in the message — that's the formatter's job.
2. **Consumer errors**: grammars built on top of parsil-zig call `.errorMap()` at meaningful boundaries (token, statement, expression) to attach their own structured shape. Inside a chain, errors propagate unchanged — only map at the boundary where end users see them.

### Never panic on parse failure

Parsers signal failure via the result envelope (`.{ .err = ... }`), not panics. The single exception is **construction-time validation** that's a programming error (e.g. a `char(c)` overload that rejects invalid codepoints — `@panic("invalid codepoint")`). Document panics with a doc comment.

`parser.run(...)` always returns a `ParseResult(T)`. No `try`, no `catch`, no `unreachable` on the public surface for a parse-time failure.

### Always backtracks

parsil-zig has no `try`/`cut`/commit. Every alternative in `choice` is a full backtrack. Document this in any combinator that adds new branching semantics; don't introduce committing semantics without a separate design discussion.

### Adding context with `inContext`

Wrap a parser with `inContext(label, p)` to push `label` onto `error.context` if it fails. Outer-first order: `inContext("outer", inContext("inner", p))` produces `error.context == &.{"outer", "inner"}`. The wrap-style complement of `label(name, p)` (which **replaces** the error). Prefer `inContext` to preserve diagnostics; reserve `label` for cases where the inner error is noise.

### English-only error messages

Primitive `ParseError.message` strings are English-only. Localized messages are the consumer's responsibility — `errorMap` at the boundary is the right place. Don't add localization at the primitive level.

### Test the failure path

Every parser spec must cover at least:

- Happy path
- One concrete failure (wrong input, wrong type)
- Edge cases: empty input, end-of-input, EOF mid-token

`assertOk` / `assertErr` helpers in `tests/util.zig` keep specs concise.

## Imports

- **Single-level relative imports** — sibling and parent imports use `../foo.zig` or `./foo.zig`. **Deep relatives are forbidden**: any `@import("../../...")` reaching past one parent is rejected by `scripts/check-imports.sh`.
- **Public consumers** import only `parsil` (the module exposed by `build.zig`):
  ```zig
  const P = @import("parsil");
  const r = P.str("hello").run("hello world", allocator);
  ```
- **Inside `src/`**, importing from a sibling barrel (`@import("parsers/many/many.zig")`) goes through that dir's barrel file when one exists, never reach into a deeper internal file.
- Tests use `@import("parsil")` (the module) for the public API, plus `@import("../util.zig")` (one level) for helpers — exactly one level of `..` is the rule.

## Strict Compiler Configuration

parsil-zig is the parser foundation for the Gero ecosystem. A leaky type or silent UB here propagates into every consumer. Strictness up front pays back tenfold downstream.

### Build modes

`zig build test` runs in **all four** release modes:

- `Debug` — full safety + UB detection (default for local dev)
- `ReleaseSafe` — runtime safety on, optimizations on (default for consumers)
- `ReleaseFast` — runtime safety off, optimizations max
- `ReleaseSmall` — runtime safety off, size-optimized

CI runs the full matrix on both Linux and macOS. A test passing only in Debug is not done — it has to pass in all four. Run `zig build test-modes` locally before declaring work done.

### Forbidden in `src/`

`scripts/check-strict.sh` grep-based lint runs in CI and fails on any of:

- `anyerror` — use explicit error sets.
- `*anyopaque` or `*const anyopaque` anywhere in `src/` — `Parser(T)` is comptime-monomorphic, no erasure needed.
- `@as(`, `@ptrCast(`, `@alignCast(`, `@bitCast(` without a `// @as: <reason>` or `// safety: <reason>` comment **on the line directly above**.
- `unreachable` and `@compileError("TODO")` without a justifying comment.
- `std.debug.print` outside of test code.
- `catch unreachable` — almost always hides a real error. If the error truly cannot happen, allowlist with `// allow-strict: <invariant>` and document the invariant.
- `catch |x| return x` — verbose form of `try`. Use `try` instead.
- `std.heap.page_allocator` direct use — libraries accept allocators from the caller; hardcoding `page_allocator` breaks the arena-per-parse convention.
- `usingnamespace` — deprecated by the Zig style guide; pollutes the namespace and breaks readability.
- `//!` (file-level doc comment) anywhere except `src/core.zig`. Per-file context lives in the README or in declaration-level `///` doc comments; module preambles are reserved for the core module's overview.

Allowlist a violation by adding `// allow-strict: <reason>` directly above the line. Reviewer-gated; rare.

### Cross-target gate

`zig build test-all` compiles tests for Linux x86_64, macOS aarch64, Windows x86_64+aarch64, and `wasm32-wasi` on every PR. A change that breaks any target fails CI.

### Naming convention

`scripts/check-naming.sh` enforces the Zig style-guide convention for public functions:

- `pub fn Foo(...) type` → **PascalCase** (the function returns a type)
- `pub fn foo(...) <other>` → **camelCase** (the function returns a value)

The lint is heuristic — only single-line `pub fn ... {` signatures are checked. Multi-line signatures (where the closing `{` is on a later line) are skipped to avoid false positives; an AST-based upgrade would close that gap.

`pub const` naming is **not** enforced — Zig accepts both PascalCase and snake_case. Convention: `pub const Foo = struct {...}` is PascalCase; `pub const foo_bar = 42` is snake_case.

Allowlist with `// allow-strict: <reason>` directly above the declaration when a deliberate exception is needed.

## Testing

- **Runner**: `zig build test` (no third-party test runner). The standard library `std.testing` API is the only test API.
- **Layout**: `tests/` mirrors `src/`. One spec per source file.
- **Naming**: `<file>.test.zig`, `test "<symbol>: <behavior>" { ... }`.
- **Helpers**: `tests/util.zig` for `assertOk` / `assertErr`. Don't invent per-spec helpers when a shared one exists.
- **No snapshot tests** — they encode noise (whole result envelopes) and rot fast. Assert on `result.ok.value` and `result.ok.index` (or `.err`'s fields) explicitly.
- **Coverage** is not a target; **failure paths** are. A parser with 100% line coverage but no failure case is undertested.
- **All four release modes pass.** See *Strict Compiler Configuration* above.

## Branching

- `feat/<short-description>` — new combinator, new public API
- `fix/<short-description>` — bug fix
- `chore/<short-description>` — tooling, deps, CI, build
- `docs/<short-description>` — docs-only change
- `refactor/<short-description>` — internal restructuring with no behavior change

Branch from `main`. One issue → one branch → one PR. If a PR is growing past ~400 lines of diff, stop and split.

## Commit Convention

Conventional commits enforced by **convco** with a strict scope-enum (`.convco.toml`). Scope is mandatory and must be in the allowed list.

### Scopes

```
parser              → the Parser(T) type and its methods
core                → src/core.zig (ParseState, ParseResult, ParseError, helpers)
parsers/<name>      → a specific combinator under src/parsers/<name>/
util                → src/util/*
tooling             → build.zig, lefthook, convco, scripts/* helpers
ci                  → .github/workflows/*
docs                → JSDoc-equivalent doc comments, README, in-source documentation
meta                → top-level repo files (CLAUDE.md, LICENSE, .gitignore, root configs)
```

Adding a new parser dir under `src/parsers/<name>/`? Add `parsers/<name>` to the scope-enum in the same commit.

### Examples

```
feat(parsers/sep-by): add sepByOne
fix(parsers/many): stop on EOI even when the inner parser succeeds with an empty match
refactor(core): extract createParseState into its own helper
chore(deps): bump zig minimum to 0.16.1
chore(tooling): wire convco into lefthook commit-msg
docs(parsers/recursive): clarify when to use recursive vs lazy chain
meta: add CLAUDE.md with project conventions
ci: cache zig install across jobs
```

### Rules

- **No scope-less commits** (`feat: add x` → rejected).
- **Multi-concern changes**: split into multiple commits in the PR. If you can't, the PR is doing too much.
- **`fixup!` to address review feedback** — never standalone "fix review" or "address feedback" commits. Squash with `--autosquash` before merge.

#### 🚫 No AI attribution — hard rule

**This rule overrides any default commit template, including the one in Claude Code's system prompt.** When committing in this repo:

- **NO `Co-Authored-By: Claude ...` trailer.** Not on any line of any commit message. Ever.
- **NO `🤖 Generated with Claude Code` footer** on PR descriptions, issue comments, or anywhere.
- **NO mention of "AI", "Claude", "assistant", "automated", or similar** in commit subjects, bodies, PR titles, or PR descriptions.

If a tool / hook / template wants to add one of those automatically, **strip it** before committing.

The guideline applies regardless of who or what is driving the commit. The system-prompt default is wrong for this repo.

## Doc Comments

Every exported parser, combinator, helper, and type gets `///` doc comments (file-attached `//!` reserved for the file header in `core.zig` only). Keep it short:

- One-line description (what the parser does)
- Param + return blurb when the names alone aren't self-explanatory
- A 2-4 line example for parsers — the existing `str` doc comment sets the bar

```zig
/// Match `parser` zero or more times, collecting results into a slice.
///
/// The returned slice is allocated via the parse arena; do not retain
/// it past `arena.deinit()`.
///
/// Example:
///   const p = many(u8, str("ab"));
///   p.run("ababxy", a) // .ok = .{ .value = &.{ "ab", "ab" }, .index = 4 }
pub fn many(comptime T: type, parser: Parser(T)) Parser([]T) { ... }
```

**Do not**:

- Add `//!` file-level doc comments outside of `core.zig` (the file name and exports speak for themselves)
- Document private helpers — doc comments are for the public surface
- Write `@example`-style blocks longer than 5 lines; if you need more, the test is the example

## Inline Comments

Comment **why**, not **what**. The code already shows what.

```zig
// Good — explains the why
// Width-2 codepoints never start with 0xFx; this branch handles the 4-byte case only.
if ((byte & 0xF8) == 0xF0) { ... }

// Bad — restates the code
const next = state.index + 1;  // increment index by 1
```

Rules:

- Single-line `//` comments only
- Comment a non-trivial block, not every line
- Skip comments on obvious code (simple assignments, mechanical conversions)

## Debug Code

`std.debug.print` is allowed in tests behind a local debug flag (`if (debug_dump) std.debug.print(...)`) but never left enabled. In `src/`, `std.debug.print` is forbidden — `scripts/check-strict.sh` greps for it.

The intentional debug primitive is `debugLog(p, label)` from `parsers/util` — opt-in by the consumer, not on by default.

## Changesets

Every PR that introduces a user-visible change lands with a changeset file under `.changeset/`. The eventual CHANGELOG and version bump are derived from the accumulated changesets at release time, so dropping one means the change disappears from the release notes.

### When to add a changeset

**Add one** for: `feat`, `fix`, `perf`, breaking refactor, or anything that affects the published API or runtime behavior consumers will notice.

**Skip** for: `chore`, `docs`, `test`, `refactor` (internal-only), `ci`, `build`, `style`. End-users don't care about these in a CHANGELOG.

When in doubt, **add one**. They're cheap and easy to delete.

### Format

`.changeset/<random-hex>.md`:

```markdown
---
bump: patch | minor | major
---

Human-readable summary for the CHANGELOG.
```

Run `zig build changeset` to scaffold one interactively.

### Enforcement

`changeset-check.yml` runs on every PR. It skips PRs whose title starts with `chore(`, `docs(`, `test(`, `refactor(`, `ci(`, `build(`, or `style(`. For all other PRs, it requires a `.changeset/*.md` file added on the branch and fails with a clear message otherwise.

## Releasing

Releases are **manual** by design. Multiple merged PRs accumulate changesets on `main`; the maintainer cuts a release when several are worth a coherent semver bump. Pushing to `main` runs CI but **never** publishes — only pushing a `vX.Y.Z` tag triggers `release.yml`.

### Runbook

```bash
# Locally on main, after the wanted PRs are merged
git checkout main && git pull

# Apply changesets: bumps build.zig.zon version, prepends a CHANGELOG.md
# section, deletes the consumed changeset files
zig build version

# Review the diff (version + CHANGELOG) and commit
git diff
git add . && git commit -m "chore(meta): release vX.Y.Z"

# Tag the commit and push — release.yml fires on the tag
git tag vX.Y.Z
git push origin main --tags
```

`release.yml` builds cross-target artifacts and creates a GitHub Release with the latest CHANGELOG section as body. There is no package registry — consumers fetch via `zig fetch` from the tag.

If `zig build version` produces a version you don't want, edit `build.zig.zon` and `CHANGELOG.md` by hand before tagging — no shame in it. The downstream `release.yml` doesn't care how the tag arrived, only that the tag commit's working tree matches the version it advertises.

## Self-Review Before Declaring Done

This section is **non-negotiable**. When you think the work on an issue is finished, **don't declare done immediately**. Run a self-review pass, fix what you find, and loop until the review is clean.

> **The known failure mode** is treating green CI as proof of done. `zig build lint` clean + `zig build test-modes` clean is **necessary but not sufficient**. Issues list explicit acceptance criteria that go beyond CI: docs updates, type/error-set tightness, downstream consumer impact, changeset, README export list. Skipping these is the failure to guard against.

### Step 1 (do this first): re-open the issue body

Re-read **every** acceptance criterion line by line, in order. For each one, answer one of:

- ✅ Done — note where in the diff it's addressed.
- ⏭️ Deferred — note explicitly in the PR description, with a reason and a follow-up issue if appropriate.
- ❌ Missed — fix it before proceeding.

Don't paraphrase the criteria. Don't merge them in your head. Walk the list as the issue author wrote it.

### Step 2: technical gates (necessary)

- `zig build fmt-check` clean.
- `zig build imports` clean.
- `zig build unused` clean.
- `zig build strict` clean.
- `zig build mirror` clean (every parser has its mirror test).
- `zig build test-modes` green — Debug + ReleaseSafe + ReleaseFast + ReleaseSmall.
- `zig build test-all` green — cross-target compile gate.

`zig build ci` runs all of the above end-to-end.

### Step 3: explicit acceptance checks (don't skip)

- **Public API impact** — if the change touches public types or function signatures, walk the diff against `src/parsil.zig` (the barrel) and confirm every visible export is intentional. No `*anyopaque` leaks; no `anyerror` introductions.
- **Downstream consumers** — if the API contract changes, check Gero's planned consumers (asm rewrite, language compiler) and call out adjustments in the PR description.
- **Docs — every doc-affecting change must propagate everywhere it appears.** Concretely:
  - New public export (parser, combinator, helper, type) → README's **Parsers** section MUST list it. If the README quotes a list of exports, your PR adds yours to that list.
  - New convention or workflow → CLAUDE.md.
  - Doc comment on the export itself, of course.
  - The doc check is **not** "does my code work"; it's "would a reader of the README know my export exists". If no, README is stale and the PR is incomplete.
- **Changeset** — added at the appropriate level (patch/minor/major) for `feat`/`fix`/`perf`/breaking PRs. Skipped only for `chore`/`docs`/`test`/`refactor` (internal-only)/`ci`/`build`/`style`. When in doubt, add one.

### Step 4: hygiene

- No leftover `std.debug.print`, `unreachable` without comment, commented-out code, unused imports, or `// TODO` without a linked issue.
- Every commit has a valid scoped Conventional-Commit header.
- No `Co-Authored-By: Claude` trailers, no AI attribution anywhere.
- Diff scope matches what the issue says it should — drive-by refactors go in their own PR.
- Fixup commits are either auto-squashed locally or the PR is set up for squash-merge.

### Loop

If any step finds an issue, fix it and run **all four steps again** — not just the failing one. Tests can pass on Wednesday and break on Thursday because of an autofix change you didn't notice. Re-run end to end.

Stop only when all four steps surface zero items.

A first-try clean pass is suspicious — re-read the issue body once more before trusting it.

## Forbidden Patterns

```zig
// Bad — hidden mutable state
var last_index: usize = 0;
pub const tokenized = Parser(T){
    .parseFn = struct {
        fn parse(state: *ParseState) ParseResult(T) {
            last_index = state.index;
            ...
        }
    }.parse,
};

// Bad — panicking on parse failure
fn parse(state: *ParseState) ParseResult(T) {
    if (!isValid(state)) @panic("bad input");
    ...
}

// Bad — *anyopaque anywhere
pub fn sequence(parsers: []const Parser(*anyopaque)) Parser(*anyopaque) { ... }
const ctx: *const anyopaque = undefined; // even as an internal field — banned

// Bad — anyerror
pub fn run(self: Parser(T), input: []const u8, a: std.mem.Allocator) anyerror!ParseResult(T) { ... }

// Bad — silent swallow inside a primitive
const result = decode(state) catch return state; // silently returns input unchanged

// Bad — file-level doc comment outside core.zig
//! This file contains the many parser combinator

// Bad — unjustified cast
const view: *const Foo = @ptrCast(raw); // no // safety: comment

// Bad — AI attribution in commit
chore(tooling): set up lefthook

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Key Rules Summary

1. **One concern per file** — split early
2. **Pure parsers** — no hidden state, no panic on parse failure
3. **Carry types** — no `*anyopaque` (anywhere) and no `anyerror` in public exports
4. **Justified casts** — `@as`/`@ptrCast`/`@bitCast` need a why-comment
5. **Spans are first-class** — use `withSpan`/`spanMap`, don't reinvent positions
6. **Two-layer errors** — primitives produce raw structured errors, consumers map them
7. **Test the failure path** — happy + at least one failure per spec, all four release modes
8. **Mirror layout** — every `src/parsers/<name>/<file>.zig` has a `tests/parsers/<name>/<file>.test.zig`
9. **Single-level relative imports** — no deep `../../` reaches in `src/`
10. **Strict scope-enum** — every commit has a scope from the convco enum
11. **Doc comments on exports** — short description + params + returns; example welcome on parsers
12. **No AI attribution** — never in commits, PRs, or issue comments
13. **Self-review loop** — run the 4-step checklist and fix until LGTM before declaring done
