---
name: token-diet
description: Audit and trim a model-facing document — SKILL.md, CLAUDE.md, system prompt, agent instruction, or any always-in-context file — for token efficiency. Triggers: "make this SKILL.md more concise", "this prompt is too long", "reduce token usage in my instructions", "token-diet this", "why is my context so expensive", "slim down this skill", "optimize for prompt caching", "cut output tokens". Applies a 10-point rubric (context-token reduction, prefix-cache optimization, output-token discipline), reports ranked before→after rewrites, applies one at a time on approval. Never strips load-bearing instructions, trigger coverage, or safety clauses. DO NOT use for general code refactoring, prose editing of docs NOT sent to a model, runtime/API token-budget tuning in application code, or structural linting covered by skilllint (line/char/frontmatter limits — call skilllint for those).
---

# Token Diet

Cut a model-facing doc's (SKILL.md, CLAUDE.md, system/agent prompt) token cost without weakening it. Every token is re-sent on (almost) every request — trimming compounds.

For a CLAUDE.md-ready, copy-paste version of these practices, see [references/PRACTICES.md](references/PRACTICES.md).

## Output discipline
- No preamble, no recap, no "Great!". Don't restate the file back to the user.
- Read the target surgically; don't paste it back wholesale. Quote only the lines you're changing.
- Report findings as a table + tight before→after pairs, not prose essays.

## The rubric (10 points)

Apply each to the target. For every hit: note location, why it costs tokens, and a concrete fix.

### A. Context-token reduction
1. **Right-size the doc.** Inline depth that's rarely needed → move to a referenced file (progressive disclosure). Flag any section that earns its tokens < once per use.
2. **Cut redundancy.** The same rule stated in two places or two phrasings → merge to one canonical statement.
3. **Prose → structure.** Convert explanatory paragraphs to bullets/tables. Denser, fewer connective tokens, easier for the model to follow.
4. **Strip filler & hedging.** Delete "it is important to note", "please", "as you may know", task-restatement, self-narration, and motivational framing. Keep the imperative.
5. **Minimal examples.** One tight example beats three. Trim setup/boilerplate inside examples to the line that demonstrates the point.
6. **Reference, don't inline.** Large blocks the model needs only sometimes (config dumps, long lists, external docs) → link out; load on demand.
7. **Delete dead / default instructions.** Guidance for cases that can't occur, or telling the model to do what it already does by default ("use good judgment", "be helpful", "think step by step" in a model that already does).
8. **Tighten the description/trigger field.** Dense trigger phrases, no wasted words — but never at the cost of trigger coverage (see guardrail).

### B. Cache optimization (prefix caching)
9. **Stable content first, volatile last.** Caches key on a stable prefix; editing an early line invalidates the cached suffix (short ~5-min TTL). Frontmatter/core rules up top, examples/tunables lower. Don't churn the head or reorder tool/section blocks between runs.

### C. Output-token reduction
10. **Mandate output discipline in the target.** If the doc governs agent behavior, ensure it instructs: terse replies, diffs not whole files, pipe noisy output through `grep`/`tail`, no preamble/recap, bounded final answer. Output tokens generate every turn — capping them is often the biggest win.

### Guardrail (non-negotiable — mirrors "don't hollow out the assertion")
Never cut load-bearing instructions, trigger phrases, safety/guardrail clauses, or behavioral contracts just to save tokens. Conciseness must preserve meaning, trigger accuracy, and behavior. If a proposed cut might change what the doc *does*, label it **low-confidence** and leave the decision to the user — don't apply it silently.

## Workflow

### 1. Identify the target
Use the path the user gave; if none, ask which file in one line.

### 2. Baseline (cheap)
- `wc -l <file>` and `wc -c <file>`; estimate tokens ≈ chars ÷ 4.
- If it's a skill, note `skilllint` structural status — don't re-derive its checks: `~/.claude/skills/ci/skilllint/bin/skilllint lint <skill-dir>` (build first if needed).

### 3. Apply the rubric
Scan against all 10 points. Each finding: location, offending text, fix.

### 4. Rank
Order by est. savings (high/med/low) weighted by risk to meaning. #9 and #10 often rank highest — they compound per-request/per-turn.

### 5. Report
Lead with a summary table:

| # | Finding | Rubric | Est. tokens saved | Confidence |
|---|---------|--------|-------------------|------------|

Then, per finding, a tight **before → after** pair. No essays.

### 6. Apply (only if asked)
One edit at a time — never a batch rewrite that's hard to review. After edits, re-validate (step below) and report the new line/char/token count and the delta.

## Validation Loop
- Re-run `skilllint` if the target is a skill — confirm 0 new errors and that referenced links still resolve.
- Confirm the `description`/trigger text still covers the original trigger phrases (diff the trigger surface; if the skill has `evals/trigger.json`, the should-trigger set must still be plausibly matched).
- Confirm no guardrail/safety/behavioral clause was removed. If any cut was low-confidence, surface it explicitly rather than counting it as done.
- Report final token delta (before → after).

## Anti-patterns (these defeat the purpose)
- Pasting the whole target file back into chat instead of quoting only changed lines.
- Batch-rewriting the entire doc so the user can't review individual cuts.
- Trading trigger coverage or a safety clause for a few tokens (guardrail violation).
- Re-implementing skilllint's structural checks instead of just running it.
- Deleting examples the model relies on for correct behavior — verify redundancy before cutting (Chesterton's Fence).
- Cosmetic edits to the stable file head, busting the prompt cache for negligible gain.
