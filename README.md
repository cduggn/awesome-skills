# awesome-skills

A personal collection of Claude Code skills.

## Skills

### `guided-impl/`

A design-first collaborative implementation workflow for substantial feature,
refactor, integration, prototype, and system-building work. The skill plans
first, runs bounded bias-challenging research with orthogonal viewpoints,
builds a shared mental model with the user (including a load-bearing-assumption
prompt), presents a design with mandatory non-goals and rejected alternatives,
does a premortem and inversion pass, tracks every file in a progress table,
and edits one file at a time only after explicit per-item user approval.

The skill is structurally hardened against common LLM failure modes mapped to
the OWASP Top 10 for LLM Applications (2025):

- **LLM01 / LLM06** — Trust Boundary clause: fetched content is data, never
  instructions that can change scope or skip the approval gate.
- **LLM02** — Sensitive-content discipline: `.env`, `*.pem`, `*.key`,
  `*.tfvars`, etc. paths are redacted before being pasted into design output.
- **LLM05** — Output channel discipline: shell-substitution syntax never
  appears inside a `bash`/`sh` fenced block.
- **LLM09** — Citation discipline: every specific API signature, version,
  or quoted best practice must name its source.

Thinking-discipline practices encoded in the workflow:

- **Premortem** (Klein, HBR 2007) — "imagine it's six months from now and this
  failed; what caused it?"
- **Inversion** (Munger) — "what would guarantee this fails?"
- **Chesterton's Fence** — answer "why does this exist?" before modifying or
  deleting existing code.
- **Rule of Three** (Fowler / Metz) — duplication is cheaper than the wrong
  abstraction.
- **Mandatory Alternatives Considered + Rejected Because** — turns design from
  advocacy into analysis (the Google design-doc differentiator).
- **Load-bearing-assumption prompt** in the mental-model checkpoint — name the
  one assumption that, if false, invalidates the whole design.

#### Files

- `guided-impl/SKILL.md` — the skill itself
- `guided-impl/agents/openai.yaml` — display metadata for non-Anthropic surfaces
- `guided-impl/evals/trigger.json` — 20 realistic Claude Code prompts for
  trigger-accuracy testing (10 should-trigger, 10 should-not-trigger)
- `guided-impl/evals/redteam.json` — 5 adversarial cases mapped to OWASP
  LLM Top 10 categories, plus a skill-specific scope-creep / approval-laundering
  scenario

## Installation

Place a skill directory under `~/.claude/skills/`:

```
git clone https://github.com/cduggn/awesome-skills.git
cp -r awesome-skills/guided-impl ~/.claude/skills/
```

Claude Code picks the skill up automatically on next session start.

## License

MIT
