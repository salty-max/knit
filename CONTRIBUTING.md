# Contributing to parsil-zig

Thanks for thinking of contributing! parsil-zig is a small but rigorously-tooled project — the conventions below exist so that every change keeps the bar consistent.

## Toolchain

Three external binaries; install once, then forget:

| Tool | Purpose | Install |
|------|---------|---------|
| **Zig 0.16.0** | Compiler + task runner | https://ziglang.org/download/ — or `brew install zig` on macOS |
| **lefthook** | Git hooks (commit-msg + pre-commit + pre-push) | `brew install lefthook` — or [other platforms](https://github.com/evilmartians/lefthook#install) |
| **convco** | Conventional-commit validator | `brew install convco` — or `cargo install convco` |

Zero Node, zero Bun, zero npm. Everything else (build, test, lint, changesets, release) is `zig build <step>` with bash helpers under `scripts/`.

After cloning:

```bash
lefthook install
zig build ci      # full local pipeline: lint + 4 release modes + cross-target compile
```

If `zig build ci` is green, you're set up correctly.

## Branching

| Prefix | When |
|--------|------|
| `feat/<short-desc>` | new combinator, new public API |
| `fix/<short-desc>` | bug fix |
| `chore/<short-desc>` | tooling, deps, CI, build |
| `docs/<short-desc>` | docs-only change |
| `refactor/<short-desc>` | internal restructuring with no behavior change |

Branch from `main`. One issue → one branch → one PR. If a PR is growing past ~400 lines of diff, stop and split.

## Commit convention

Conventional commits, validated by **convco** with a strict scope-enum (`.versionrc`). Scope is mandatory.

### Allowed scopes

```
parser            → the Parser(T) type and its methods
core              → src/core.zig (ParseState, ParseResult, ParseError, helpers)
parsers/<name>    → a specific combinator under src/parsers/<name>/
util              → src/util/*
tooling           → lefthook, build.zig, scripts, convco
ci                → .github/workflows/*
docs              → doc comments, README, in-source documentation
meta              → top-level repo files (LICENSE, .gitignore, root configs)
```

Adding a new parser dir? Add `parsers/<name>` to the scope-enum in the same commit.

### Examples

```
feat(parsers/sep-by): add sepByOne
fix(parsers/many): stop on EOI even when the inner parser succeeds with an empty match
refactor(core): extract createParseState into its own helper
chore(deps): bump zig minimum to 0.16.1
docs(parsers/recursive): clarify when to use recursive vs lazy chain
ci: cache zig install across jobs
```

## Changesets

Every PR with a user-visible change drops a markdown file under `.changeset/`. Use:

```bash
zig build changeset
```

Skip changesets for `chore`/`docs`/`test`/`refactor`/`ci`/`build`/`style`. The `changeset-check` workflow auto-skips those titles; for everything else, it fails the PR if no changeset is present.

See `.changeset/README.md` for the format.

## Test layout

`tests/` mirrors `src/`. Every `src/parsers/<name>/<file>.zig` has a matching `tests/parsers/<name>/<file>.test.zig`. The mirror is enforced by `scripts/check-mirror.sh`; CI fails on a missing test file.

Tests should:
- Cover the happy path
- Cover **at least one** failure case (wrong input, EOF, etc.)
- Use `std.testing.allocator` for any test that allocates (the `check-testing-allocator.sh` lint enforces this)

Helpers live in `tests/util.zig` (`assertOk`, `assertOkAt`, `assertErr`, …). Imported as `@import("util")`.

## Self-review loop (required)

Before declaring a non-trivial task done, walk this checklist; if any step finds something, fix it and re-run **all** steps.

### Step 1 — re-read the issue body

Walk the acceptance criteria line by line. Each one is either ✅ Done (note where in the diff it's addressed), ⏭️ Deferred (note explicitly with a reason and follow-up issue), or ❌ Missed (fix it).

### Step 2 — technical gates

```bash
zig build ci    # passes locally
```

If `zig build ci` isn't green locally, the PR isn't ready. CI is the safety net, not the iteration loop.

### Step 3 — code-quality / language-idioms

Walk every line of the diff with two lenses:
- Is it idiomatic Zig? No `*anyopaque`, no `anyerror`, justified casts (`// @as: ...` / `// safety: ...`), no `catch unreachable` without `// allow-strict: ...`, no `usingnamespace`.
- Edge cases handled? Failure paths loud? `set -euo pipefail` + trap on bash scripts? Cross-target portability?

### Step 4 — hygiene

- No leftover `std.debug.print` in `src/`
- No `// TODO` without an issue link
- Conventional-commit headers valid; every commit has a scope
- Diff scoped to what the issue says — drive-by refactors go in their own PR
- Changeset added if appropriate

## Where to ask questions

- Open a GitHub issue for bugs and feature requests
- For contribution scope or design questions on a specific issue, comment on the issue itself
