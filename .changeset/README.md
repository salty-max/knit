# Changesets

Every PR with a user-visible change drops a markdown file here. At release time,
`zig build version` consumes them, bumps `build.zig.zon`'s version, prepends a
section to `CHANGELOG.md`, and deletes the consumed files.

Skip changesets for `chore` / `docs` / `test` / `refactor` (internal-only) /
`ci` / `build` / `style`. When in doubt, add one — they're cheap.

## Format

```markdown
---
bump: patch | minor | major
---

Human-readable summary for the CHANGELOG.
```

- `bump` is required and must be one of `patch`, `minor`, `major`.
- Summary is the first non-empty line after the closing `---`. It becomes the
  CHANGELOG bullet verbatim, so write it for end users, not for reviewers.

## Workflow

```bash
zig build changeset            # interactive: pick bump + summary
git add .changeset/<file>.md   # commit alongside your PR
```

At release time (maintainer only):

```bash
git checkout main && git pull
zig build version              # consumes .changeset/*.md, bumps version, updates CHANGELOG
git diff                       # review the diff
git add . && git commit -m "chore(meta): release vX.Y.Z"
git tag vX.Y.Z && git push origin main --tags
```

The release.yml workflow fires on the tag.

## Why manual

Atlassian's `@changesets/cli` would work but pulls Node into the dev loop. The
format above is a hand-rolled subset that does what we need with two bash
scripts and zero runtime dependencies. See `scripts/changeset-new.sh` and
`scripts/changeset-version.sh`.
