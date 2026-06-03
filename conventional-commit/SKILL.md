---
name: conventional-commit
description: USE THIS SKILL whenever the user wants to commit, push, or open a PR for their changes — "commit this", "commit my changes", "git commit", "save my work", "commit and push", "open a PR for this", "ship it", "wrap this up", or any request to record staged/unstaged work in git. Stages the right files, splits unrelated changes into atomic commits, and writes Conventional Commits (type(scope): subject) with a terse, token-aware body that explains the WHY and flags breaking changes — never the obvious WHAT. Then pushes and opens a PR with a matching title/body. DO NOT use for inspecting history, reverting, rebasing, merge-conflict resolution, branch management, or writing release notes/changelogs — those are different git tasks.
---

# Conventional Commit

Record changes as clean Conventional Commits, then push and open a PR. The message is for the next engineer (often future-you) skimming `git log`: it should answer *why this change exists*, because the diff already shows *what changed*. Wasted words here are re-read forever.

## Output discipline

This skill commits work; it does not narrate. Keep your own output to the user minimal.

- No preamble ("I'll now commit your changes…"), no recap of the diff, no "Great!".
- Don't paste the diff back. Don't explain git to the user.
- After committing: report the one-line subject(s) and the PR URL. That's it.
- The commit message itself follows the same rule — terse, no filler, no self-narration.

## Workflow

Run the context-gathering commands together in one batch (they're independent):

- `git status` — what's staged vs. unstaged vs. untracked
- `git diff HEAD` — the actual changes (staged + unstaged)
- `git branch --show-current` — current branch
- `git log --oneline -10` — match the repo's existing type/scope conventions

Then:

1. **Decide what to commit.** If nothing is staged, stage the relevant files (`git add`). Don't blindly `git add -A` if untracked files look unrelated (build output, secrets, scratch files) — surface those instead.
2. **Check for mixed concerns.** If the changes span unrelated purposes (e.g. a bugfix *and* a dependency bump *and* a docs edit), propose splitting into atomic commits and let the user confirm before proceeding. One commit = one logical change keeps history bisectable and revertable.
3. **Branch if on the default branch.** If on `main`/`master`, create a topic branch first (`git checkout -b <type>/<short-slug>`) so the PR has somewhere to go.
4. **Write the commit(s)** in Conventional Commits format (below).
5. **Push** the branch to origin (`git push -u origin <branch>`).
6. **Open the PR** with `gh pr create`, reusing the commit subject as the title and the bodies as the PR body. For multi-commit branches, write a PR body that summarizes the set.

Batch independent tool calls (stage + commit, or push + pr-create prep) into single messages where order allows.

## Conventional Commits format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type** — pick the one that matches the change's intent:

| type | use for |
|------|---------|
| `feat` | a new user-facing capability |
| `fix` | a bug fix |
| `refactor` | restructuring with no behavior change |
| `perf` | a performance improvement |
| `docs` | documentation only |
| `test` | adding/fixing tests only |
| `build` | build system, dependencies, packaging |
| `ci` | CI/CD config |
| `chore` | maintenance that doesn't fit above (e.g. config, tooling) |
| `style` | formatting/whitespace, no logic change |

**Scope** (optional) — the affected area, e.g. `auth`, `api`, `parser`. Include it when it sharpens the line; omit when the change is broad or the scope is obvious. Match scopes already used in the repo's log.

**Subject** — imperative mood ("add", not "added"/"adds"), no trailing period, ≤ ~50 chars, lowercase after the colon. It completes the sentence "this commit will…".

## Body policy

Write a body by default — but make it earn its tokens. The body explains **why**: the motivation, the constraint, the thing that wasn't obvious from reading the diff. It does **not** restate the what ("changed function X to do Y" is already visible in the diff).

- Keep it to 1–3 tight bullets or a short sentence. Wrap at ~72 chars.
- Good body content: the reason for the change, a tradeoff taken, a non-obvious consequence, a linked issue.
- Skip the body only when the subject is genuinely complete on its own (typo fix, version bump, formatting) — forcing a body there just adds noise.

**Breaking changes** must always be flagged — add `!` after the type/scope *and* a footer:

```
feat(api)!: drop support for v1 auth tokens

BREAKING CHANGE: clients using v1 bearer tokens must re-authenticate
to obtain v2 tokens. v1 endpoints return 410 Gone.
```

Other footers when relevant: `Refs: #123`, `Closes: #123`, `Co-authored-by: …`.

**Trailers follow convention.** Match whatever the repo's recent log already does, and honor any standing instruction the user has set (e.g. a CLAUDE.md that mandates a `Co-Authored-By` trailer). Don't impose or strip attribution trailers on your own judgment — defer to the established convention.

## Examples

**Self-explanatory — subject only:**
```
docs(readme): fix broken link to contributing guide
```

**Bug fix — body gives the why:**
```
fix(cache): evict entries on write, not just on read

Stale reads were possible when a key was updated by another node;
read-path eviction alone left the local copy live until its TTL.
```

**Feature — body notes a deliberate constraint:**
```
feat(upload): accept multipart files up to 50MB

Cap is enforced server-side to match the CDN's per-object limit;
larger files must use the presigned direct-to-S3 path instead.
```

**Splitting mixed changes** — if a diff bundles a fix, a dep bump, and docs, propose:
```
fix(parser): handle trailing commas in array literals
build(deps): bump serde to 1.0.210
docs(parser): document array-literal grammar
```
and commit them separately once the user confirms.

## Anti-patterns

- Vague subjects: `fix: bug`, `chore: updates`, `wip`, `misc changes`. Say what and why.
- Past tense / sentence case: `Fixed the login bug.` → `fix(auth): reject expired session tokens`.
- Body that parrots the diff: `Changed line 42 to call validate()`. The reader can see line 42.
- One commit smuggling several unrelated changes. Split it.
- Overriding the repo's trailer convention — don't invent or delete `Co-authored-by` / `Generated with` trailers on a hunch; follow the log and any standing user instruction (see "Trailers follow convention").
