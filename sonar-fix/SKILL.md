---
name: sonar-fix
description: USE THIS SKILL whenever the user wants to resolve SonarQube / SonarCloud / SonarLint findings — "fix these Sonar issues", "clear the Sonar violations on this PR", "sort out the code smells Sonar flagged", "the quality gate is failing", a pasted list of Sonar rule keys (e.g. go:S1192, java:S3776, S2589), a SonarCloud issue export (CSV/JSON), or any request to address reliability/maintainability/security findings from Sonar. Go-leaning but handles any language. The skill works token-frugally: it parses the findings, triages by type, fixes the real defect at the correct layer WITHOUT contorting code to satisfy a rule, checks wider-codebase impact before removing or renaming anything, verifies with build/tests (not a re-scan), and stops instead of chasing the score into a refactor doom loop. DO NOT use for running a Sonar scan from scratch, configuring the scanner/quality gate, triaging which issues to silence as a project policy, or non-Sonar lint (golangci-lint, ESLint) unless the user maps them onto Sonar rules.
---

# Sonar Fix

Resolve Sonar findings at minimum token cost. Fix the real defect, not the symptom; never damage correct code just to turn a rule green; check who else depends on what you touch; verify by compiling and testing, not by re-scanning; and know when the right answer is "mark this won't-fix" rather than refactor.

## Output discipline (the user is token-constrained)

- No preamble, no recap, no "Great!", no restating the findings back. Skip narration of what you're "about to do."
- Never paste whole files, full diffs, or the entire findings list into the chat. Report only the decisive lines.
- Read surgically: the flagged line and the symbol around it, not whole files. `grep -n` to the line, then `Read` with `offset`/`limit`.
- Final reply is a compact per-issue ledger: `rule  file:line  → action` (one line each), then a single verification line. Group identical-rule fixes into one line where they share a fix.

## Workflow

### 1. Parse the findings
From the pasted list / CSV / JSON, extract for each issue: **rule key** (e.g. `go:S1192`), **type/quality** (Bug, Vulnerability, Code Smell, Security Hotspot — or the Clean Code qualities Reliability/Security/Maintainability), **severity/impact**, **file:line**, **message**. If the message alone doesn't name the rule's intent, that rule key tells you exactly what Sonar wants — reason from it.

Then **group**: by rule (so you learn each fix pattern once) and by file (so you read and edit each file once). Drop duplicates and any issue whose line no longer matches the current code — stale findings are common and chasing them is wasted work; note them as already-resolved rather than inventing a change.

### 2. Triage — fix order by value, not by list order
- **Bugs / Vulnerabilities (Reliability, Security)** first — these are real defects: nil deref, unchecked error, resource leak (missing `defer Close`), float `==`, injection, weak crypto. Fix the logic.
- **Mechanical smells** next — unused import/var, duplicated literal → constant, redundant cast, missing `default`. Cheap, local, low-risk.
- **Structural smells** (cognitive complexity S3776, duplicated blocks, too many params, deep nesting) — higher risk: restructuring can change behavior or ripple. Smallest safe restructure only; see step 4. But first sanity-check the finding against the code: a complexity or duplication flag on code that is already short and obvious is a non-issue — Sonar thresholds misfire, and findings go stale after edits. Don't refactor simple, correct code to chase a number; report it as not-applicable.
- **Security Hotspots** are *review* requests, not auto-fixes. Decide: is it exploitable here? If yes, fix and say how; if it's safe-in-context, say why and recommend marking it Reviewed/Safe rather than changing working code.

### 3. Chesterton's fence — understand why the code is the way it is
Many smells exist for a reason. A "useless" assignment may be a deliberate default; a "redundant" nil check may guard a real edge; an "unused" parameter may exist to satisfy an interface; a flagged literal may be intentionally inline for clarity. Before deleting or rewriting, answer *why is this here?* — cheapest evidence first: the surrounding code's intent, the doc comment, a sibling usage, then `git blame`/`git log -p` on the line. If it's load-bearing, the right move may be to fix it differently — or to mark it won't-fix — not to remove it.

### 4. Fix at the correct layer (smallest change that matches idiom)
- One minimal edit per issue. Don't refactor neighbouring code, rename for taste, or "improve" style while here — that adds tokens, risk, and new smells.
- **Stay in remit.** Your job is to resolve the findings. If the request bundles unrelated work alongside them — "while you're in there, rename the package / split the files / bump the language version" — recognise that those are wide-impact changes that can ripple across the codebase (the exact thing the findings *don't* ask for). Do the Sonar fixes, then flag the bundled refactors as out of scope and let the user decide, rather than silently executing them. A package rename or file split to clear a code smell is almost never what the finding wanted.
- Match the surrounding idiom and the language's conventions. For **Go**, prefer the idioms already in the file: `fmt.Errorf("...: %w", err)` to wrap, early returns over nesting, small focused functions when splitting for complexity, `defer` for cleanup, table-driven structure where it already exists. Mirror the file — don't import a foreign style.
- For cognitive-complexity/duplication rules, the goal is *behavior-preserving* extraction. Extract a guard clause or a helper; do not change what the code computes. If you can't reduce complexity without altering behavior or readability, say so and recommend annotating instead of forcing it.

### 5. Wider-codebase impact check (before the edit lands, not after)
Sonar issues are local; their fixes often aren't. **Before removing or renaming any symbol that could be referenced elsewhere** — an exported identifier, an interface method, a struct field, a public function parameter, a constant — confirm it's truly safe:
- `grep -rn 'Symbol' --include='*.<ext>' .` for call sites.
- Consider non-grep-visible uses: reflection, struct tags / (de)serialization, dependency injection, build-tagged files, generated code, and interface satisfaction (does removing this param break the interface?).
- If removal would break a contract, don't. Satisfy the rule another way (e.g. `_ =` the value, blank-identifier the param) or mark it won't-fix. A green rule that breaks the build or an API is a regression, not a fix.

### 6. Verify — compile and test, do not re-scan
Your verification signal is the toolchain, not a fresh Sonar run (which is slow, may need a server, and re-scanning to watch the number drop is the doom loop).
- Go: `go build ./... 2>&1 | tail -n 20`, then `go test ./<touched-pkg>/... -count=1 2>&1 | tail -n 15`, and `go vet ./... 2>&1 | tail -n 15` if you changed a signature or behavior. Other languages: the equivalent build + targeted test.
- Knock-on scope = what you touched: a shared/exported symbol means you also exercise its dependents (`grep -rln` the symbol, test those packages). If a fix made a test fail, that test is now your signal — that means the "smell" was load-bearing behavior; revisit step 3, don't paper over it.

### 7. Know when to stop (anti-doom-loop)
- Fix each issue once across all its occurrences, then move on. Don't iterate trying to drive a local score to zero.
- If fixing rule A reliably spawns rule B (extract a constant → naming rule; split a function → another complexity flag), you're trading smells, not removing them — stop and report the tradeoff instead of looping.
- When the honest answer is "the code is correct and the rule is wrong for this context," don't contort the code. Recommend marking it in Sonar (Won't Fix / Accepted) or, if the project uses it, a justified `//NOSONAR` (or language equivalent) — and say why. Readable correct code beats a satisfied rule.
- If which fix is right is genuinely ambiguous, ask in one line rather than guess.

## Anti-patterns (these defeat the purpose)
- Dumping the whole findings list or full files into chat.
- Removing an "unused" export/param/field without grepping for callers, reflection, or interface use — then breaking the build.
- Refactoring for cognitive complexity in a way that changes behavior, just to clear the number.
- Re-running the Sonar scan repeatedly to watch the score, instead of verifying with build + tests.
- Contorting correct, readable code to satisfy a false-positive rule when marking it won't-fix is the honest fix.
- Trading one rule for another in a loop instead of recognizing the tradeoff and stopping.
