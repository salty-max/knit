<!--
Title format: <type>(<scope>): <subject>
  e.g. feat(parsers/sep-by): add sepByOne
       fix(parsers/many): stop on EOI when inner succeeds with empty match
       chore(ci): cache zig install across jobs
See CONTRIBUTING.md "Commit convention" for the allowed scopes.
-->

## Summary

<!-- 1-3 sentences on what changed and why. The why matters more than the what. -->

## Linked issue

Closes #

## Self-review

### Step 1 — issue acceptance criteria

<!-- Walk every acceptance criterion from the linked issue. Don't paraphrase. -->

- [ ] Every acceptance criterion explicitly addressed (or ⏭️ deferred with a follow-up issue)

### Step 2 — technical gates

- [ ] `zig build ci` clean locally
- [ ] No `--no-verify` on the final commit (or, if used, justified below)

### Step 3 — code quality / Zig idioms

- [ ] No `*anyopaque`, no `anyerror`, no `catch unreachable` without `// allow-strict: <reason>`
- [ ] Justified casts (`// @as: ...` / `// safety: ...`) where applicable
- [ ] Edge cases handled and tested (happy path + at least one failure)
- [ ] Memory ownership documented when slices are returned to consumers

### Step 4 — hygiene

- [ ] Conventional-commit headers with a valid scope on every commit
- [ ] Diff scoped to what the issue says (drive-by refactors moved to their own PR)
- [ ] Changeset added if this is `feat` / `fix` / `perf` / breaking
