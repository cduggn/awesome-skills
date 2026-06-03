---
name: go-test-fix
description: USE THIS SKILL whenever a Go unit test is failing and the user wants it diagnosed and fixed — "this test is broken", "go test fails", "fix the failing test", "TestFoo is red", "why is this panicking in test", "the build won't compile", a pasted `go test` failure / panic / `--- FAIL` output, or any request to find the root cause of a Go test failure and resolve it. Handles compile/build errors, runtime panics, and assertion failures. The skill works token-frugally: it isolates the failing test, reads only the minimal code, finds the true root cause, fixes the correct layer (test vs. production code) WITHOUT weakening or changing the behavior under assertion, and checks for knock-on breakage before declaring done. DO NOT use for flaky/timing-only failures the user wants left alone, non-Go tests, writing new tests from scratch, or general refactors — those are different tasks.
---

# Go Test Fix

Diagnose and fix failing Go unit tests at minimum token cost. Find the real root cause, fix the correct layer, never make a test green by hollowing out what it checks, and confirm you broke nothing else.

## Output discipline (non-negotiable — the user is token-constrained)

- No preamble, no recap, no "Great!", no restating the task. Skip narration of what you're "about to do."
- Never paste full test output, full files, or full diffs into the chat. Pipe noisy commands through `tail`/`grep` and report only the decisive lines.
- Read surgically: the failing test function and the one symbol it exercises — not whole files. Use `grep -n` to jump to line numbers, then `Read` with `offset`/`limit`.
- Run a command once, capture to a temp file, then `grep` that file. Don't re-run the suite to re-see output you already have.
- Final reply ≤ ~6 lines: root cause (1 line), fix locus + what changed (1–2 lines), verification result (1 line), knock-on status (1 line).

## Workflow

### 1. Isolate (cheap signal first)
- If the user named the test/package, go straight to it. Otherwise find the failure cheaply, narrowest first:
  - Compile? `go build ./... 2>&1 | tail -n 20`
  - Else run the suspect package: `go test ./pkg/... -run '^TestName$' -count=1 2>&1 | tail -n 40`
  - Only fall back to `go test ./... -count=1 -failfast 2>&1 | tail -n 40` if you don't know where it is. Capture to `/tmp/gtf.out` and grep it (`-E 'FAIL|panic|\.go:[0-9]'`) rather than re-running.
- `-count=1` disables the test cache so you see the real current state.

### 2. Classify
Each class has a different root-cause path:
- **Compile/build error** → missing/renamed symbol, signature change, wrong types, unused import. The error line points at the file:line.
- **Panic** → read the stack's *first frame inside the code under test*, not the testing-framework frames. Usual causes: nil deref, index/slice bounds, nil map write, failed type assertion.
- **Assertion failure** → got vs. want mismatch. The question is *which side is wrong*.

### 3. Root cause (read minimally)
Pull only what's needed to explain the failure:
- `grep -n` the symbol the test calls; `Read` just that function.
- For an assertion mismatch, determine the *intended* behavior before touching anything. Evidence, cheapest first: the assertion's own intent and the test's name → doc comment on the symbol → sibling passing tests for the same symbol → `git log -p -L :FuncName:file.go` or `git blame` to see if test or impl changed last.

### 4. Decide locus — test or production code?
This is the crux. Default assumption: **the test encodes the contract; the production code is what regressed.** A red test usually means the code broke, so fix the code.

Fix the **test** only when you can articulate why the test itself is wrong — e.g. it asserts a stale value after an intentional behavior change, sets up invalid fixtures, calls the API incorrectly, or depends on removed surface. State that reason in one line.

Never make a test pass by weakening what it verifies: do not delete/loosen assertions, change expected values to match buggy output, add `t.Skip`, comment out cases, or relax tolerances *unless* you've established the old expectation was genuinely wrong. Making red turn green is not the goal — making the code correct while the test still meaningfully guards it is.

If which side is wrong is genuinely ambiguous from the evidence, stop and ask in one line rather than guess.

### 5. Fix (smallest change)
One minimal edit at the correct layer. Don't refactor surrounding code, rename things, or "improve" style while here — that adds tokens and risk. Match surrounding idiom.

### 6. Verify + knock-on check
- Re-run the exact target: `go test ./pkg/... -run '^TestName$' -count=1 2>&1 | tail -n 10`.
- Knock-on scope depends on what you touched:
  - Test-only change → re-run that package: `go test ./pkg/... -count=1 2>&1 | tail -n 10`.
  - Changed production code with an exported/shared symbol → also exercise dependents. Find them cheaply: `grep -rln 'pkgname\.Symbol' --include='*.go' .` or `go list -deps` reverse lookup, then `go test` those packages. If many, run the module: `go test ./... -count=1 2>&1 | tail -n 15`.
  - If you changed a signature or behavior, run `go vet ./... 2>&1 | tail -n 15` too.
- If the fix made another test fail, that test is now your new signal — repeat from step 2; don't paper over it.

## Anti-patterns (these defeat the purpose)
- Dumping the whole failing file or full `go test` log into chat.
- Reading entire files when the failure points at a specific line.
- Re-running the full suite repeatedly instead of scoping with `-run` and grepping cached output.
- Editing the assertion to match wrong output just to go green.
- Fixing the symptom in the test when the code under test is the actual regression (or vice-versa).
- Silent broad refactors that introduce knock-on failures you don't check for.
