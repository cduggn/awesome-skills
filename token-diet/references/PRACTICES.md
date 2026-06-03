# Token-efficiency practices (instruction-author edition)

Copy-paste–ready, imperative one-liners for use inside a CLAUDE.md, system prompt, or any model-facing instruction file. This is the human/author-facing companion to the audit rubric in `SKILL.md`; the rubric is the auditor's voice, this is the author's.

## Context-token reduction
1. Keep always-in-context docs lean; push rarely-needed depth to referenced files and load on demand.
2. State each rule once, in one place — no restating the same instruction two ways.
3. Prefer bullets and tables over paragraphs.
4. Cut filler: no "it is important to note", "please", "as you know", task-restatement, or self-narration.
5. Use one minimal example, not three; trim example boilerplate to the demonstrating line.
6. Link out to large or occasional content instead of inlining it.
7. Delete instructions for impossible cases and anything the model already does by default.
8. Make trigger/description text dense but complete — short words, full coverage.

## Cache optimization
9. Put stable content (frontmatter, core rules) first and volatile content (examples, tunables) last; avoid editing the head of the file, which invalidates the cached prefix (short ~5-min TTL).

## Output-token reduction
10. Tell the agent to be terse: diffs not whole files; pipe noisy output through `grep`/`tail`; no preamble/recap; bounded final reply.

## The one rule that overrides the other ten
Never cut a load-bearing instruction, trigger phrase, or safety clause to save tokens. Brevity must not change behavior. When unsure, keep it.
