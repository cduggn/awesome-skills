---
name: token-diet
description: USE THIS SKILL when the user wants a skill, CLAUDE.md, system prompt, agent instruction, or any always-in-context document audited and trimmed for token efficiency — "make this SKILL.md more concise", "this prompt is too long", "reduce token usage in my instructions", "token-diet this", "why is my context so expensive", "slim down this skill", "optimize for prompt caching", "cut output tokens". Applies a 10-point rubric covering context-token reduction, prefix-cache optimization, and output-token discipline, then reports ranked before→after rewrites and applies them one at a time on approval. It never strips load-bearing instructions, trigger coverage, or safety clauses to save tokens. DO NOT use for general code refactoring, prose editing of docs that are NOT sent to a model, runtime/API token-budget tuning in application code, or structural linting already covered by skilllint (line/char/frontmatter limits) — call skilllint for those.
---

# Token Diet

Audit a model-facing document (SKILL.md, CLAUDE.md, system/agent prompt) and cut its token cost without weakening what it does. Every token in these files is re-sent on (almost) every request — trimming compounds.

For a CLAUDE.md-ready, copy-paste version of these practices, see [PRACTICES.md](PRACTICES.md).

## Contents
- Output discipline
- The rubric (10 points)
- Workflow
- Validation Loop
- Anti-patterns

## Output discipline (this skill is itself token-frugal)
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
9. **Stable content first, volatile last.** Prompt caches key on a stable prefix; any edit to an early line invalidates the cached suffix, and the cache has a short (~5 min) TTL. Put frontmatter and core rules (rarely edited) up top; put examples, variable, or frequently-tuned content lower. Don't churn the head of the file. Don't reorder tool/section blocks between runs.

### C. Output-token reduction
10. **Mandate output discipline in the target.** If the audited doc governs an agent's behavior, ensure it instructs: terse replies, return diffs not whole files, pipe noisy command output through `grep`/`tail`, no preamble/recap, and a bounded final answer. Output tokens are generated every turn — capping them is often the biggest single win.

### Guardrail (non-negotiable — mirrors "don't hollow out the assertion")
Never cut load-bearing instructions, trigger phrases, safety/guardrail clauses, or behavioral contracts just to save tokens. Conciseness must preserve meaning, trigger accuracy, and behavior. If a proposed cut might change what the doc *does*, label it **low-confidence** and leave the decision to the user — don't apply it silently.

## Workflow

### 1. Identify the target
A SKILL.md, CLAUDE.md, system/agent prompt, or instruction file. Use the path the user gave; if none, ask which file in one line.

### 2. Baseline (cheap)
- `wc -l <file>` and `wc -c <file>`; estimate tokens ≈ chars ÷ 4.
- If it's a skill, note `skilllint` structural status — don't re-derive its checks: `~/.claude/skills/ci/skilllint/bin/skilllint lint <skill-dir>` (build first if needed).

### 3. Apply the rubric
Scan the target against all 10 points. Collect findings; each carries a location, the offending text, and a fix.

### 4. Rank
Order by estimated savings (high / med / low) weighted by risk to meaning. Cache (#9) and output discipline (#10) often rank highest because they compound per-request / per-turn.

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
- "Optimizing" by deleting examples the model actually relies on to get behavior right — verify the example is redundant before cutting it (Chesterton's Fence).
- Editing the stable head of a file for cosmetic reasons, invalidating the prompt cache for a negligible gain.
