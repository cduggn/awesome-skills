---
name: sonar-fix
description: Resolve SonarQube / SonarCloud / SonarLint findings — "fix these Sonar issues", "clear the Sonar violations on this PR", "fix the code smells Sonar flagged", "the quality gate is failing", a pasted list of Sonar rule keys (e.g. go:S1192, java:S3776, S2589), a SonarCloud issue export (CSV/JSON), or any request to address reliability/maintainability/security findings from Sonar. Go-leaning but any language. Parses findings, triages by type, fixes the real defect at the correct layer WITHOUT contorting code to satisfy a rule, checks wider-codebase impact before removing/renaming, verifies with build/tests (not a re-scan), stops instead of chasing the score into a refactor doom loop. DO NOT use for running a scan from scratch, configuring the scanner/quality gate, project-policy triage of which issues to silence, or non-Sonar lint (golangci-lint, ESLint) unless mapped onto Sonar rules.
---

# Sonar Fix

## Output discipline (user is token-constrained)
- No preamble/recap/narration; don't restate findings.
- Never paste whole files, full diffs, or the full findings list — only decisive lines.
- Read surgically: `grep -n` to the line, then `Read` with `offset`/`limit` — not whole files.
- Final reply: per-issue ledger `rule  file:line → action` (one line each; group identical-rule fixes), then one verification line.

## Workflow

### 1. Parse
Extract per issue: **rule key** (e.g. `go:S1192`), **type/quality** (Bug/Vulnerability/Code Smell/Security Hotspot, or Reliability/Security/Maintainability), **severity**, **file:line**, **message**. The rule key tells you exactly what Sonar wants — reason from it if the message is vague.
**Group** by rule (learn each fix once) and by file (read/edit each once). Drop duplicates and stale findings (line no longer matches code — common); note as already-resolved, don't invent a change.

### 2. Triage — fix order by value, not list order
- **Bugs/Vulnerabilities (Reliability/Security)** first — real defects: nil deref, unchecked error, resource leak (missing `defer Close`), float `==`, injection, weak crypto. Fix the logic.
- **Mechanical smells** next — unused import/var, duplicated literal → constant, redundant cast, missing `default`. Cheap, local, low-risk.
- **Structural smells** (cognitive complexity S3776, duplicated blocks, too many params, deep nesting) — higher risk. Smallest safe restructure only (step 4). First sanity-check: a complexity/duplication flag on already-short, obvious code is a non-issue (thresholds misfire, findings go stale) — report not-applicable, don't refactor correct code to chase a number.
- **Security Hotspots** are *review* requests, not auto-fixes. Exploitable here? If yes, fix and say how; if safe-in-context, say why and recommend marking Reviewed/Safe.

### 3. Chesterton's fence — why is the code this way?
Many smells exist for a reason: a "useless" assignment may be a deliberate default; a "redundant" nil check may guard a real edge; an "unused" param may satisfy an interface; an inline literal may be intentional for clarity. Before deleting/rewriting, check cheapest evidence first — surrounding intent, doc comment, sibling usage, then `git blame`/`git log -p`. If load-bearing, fix it differently or mark won't-fix — don't remove it.

### 4. Fix at the correct layer (smallest idiomatic change)
- One minimal edit per issue. Don't refactor neighbours, rename for taste, or "improve" style — adds tokens, risk, new smells.
- **Stay in remit.** If the request bundles wide-impact work ("while you're in there, rename the package / split files / bump the language version"), do the Sonar fixes, then flag the bundled refactors as out of scope for the user to decide — don't silently execute them. A package rename or file split to clear a smell is almost never what the finding wanted.
- Match the file's idiom. **Go:** `fmt.Errorf("...: %w", err)` to wrap, early returns over nesting, small focused functions when splitting for complexity, `defer` for cleanup, table-driven where it already exists. Mirror the file; don't import a foreign style.
- For complexity/duplication, do *behavior-preserving* extraction (guard clause / helper); never change what's computed. If you can't without altering behavior/readability, say so and recommend annotating.

### 5. Wider-codebase impact check (before the edit lands)
Fixes for local issues often aren't local. **Before removing/renaming any symbol referenced elsewhere** (exported identifier, interface method, struct field, public param, constant), confirm it's safe:
- `grep -rn 'Symbol' --include='*.<ext>' .` for call sites.
- Consider non-grep uses: reflection, struct tags/(de)serialization, DI, build-tagged files, generated code, interface satisfaction.
- If removal breaks a contract, don't — satisfy the rule another way (`_ =` the value, blank-identifier the param) or mark won't-fix. A green rule that breaks the build/API is a regression.

### 6. Verify — compile and test, don't re-scan
Verification = toolchain, not a fresh Sonar run (slow, may need a server, and watching the number is the doom loop).
- Go: `go build ./... 2>&1 | tail -n 20`, then `go test ./<touched-pkg>/... -count=1 2>&1 | tail -n 15`, and `go vet ./... 2>&1 | tail -n 15` if you changed a signature/behavior. Other languages: equivalent build + targeted test.
- Scope = what you touched. A shared/exported symbol means you also test its dependents (`grep -rln` the symbol). A failing test means the "smell" was load-bearing behavior — revisit step 3, don't paper over it.

### 7. Know when to stop (anti-doom-loop)
- Fix each issue once across all occurrences, then move on. Don't iterate to drive a local score to zero.
- If fixing rule A reliably spawns rule B (constant → naming rule; split → another complexity flag), you're trading smells — stop and report the tradeoff.
- When the honest answer is "code is correct, rule is wrong here," don't contort it. Recommend marking Won't Fix/Accepted in Sonar, or a justified `//NOSONAR` (or equivalent) — and say why.
- If the right fix is genuinely ambiguous, ask in one line rather than guess.

## Anti-patterns
Dumping files/findings into chat; removing an export/param/field without a grep + reflection/interface check; behavior-changing complexity refactors; re-scan-to-watch-the-score loops; contorting correct code instead of won't-fix; trading rule A for rule B in a loop.
