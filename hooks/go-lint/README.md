# Go lint hooks

Two Claude Code hooks that keep Go code formatted and linted as the agent works,
using a two-tier strategy: fast feedback per edit, full CI gate when the agent
finishes.

| Script | Hook event | Scope | Action |
|---|---|---|---|
| `go-lint.sh` | `PostToolUse` (`Write`/`Edit`/`MultiEdit`) | edited file's package | `gofmt -w` + `goimports -w` (if installed) + `golangci-lint run --fast-only` |
| `go-ci.sh` | `Stop` (agent finishes a turn) | whole module | `go build ./...` + `go vet ./...` + `golangci-lint run ./...` |

## How it works

Both scripts use the hook **exit-code contract**:

- **exit 0** — silent pass, nothing shown.
- **exit 2** — `stderr` is fed back to Claude so it can auto-fix the reported issues.

`go-lint.sh` reads the edited file path from the hook's stdin JSON
(`.tool_input.file_path`), bails immediately on non-`.go` files, formats in place
(formatting never blocks), then lints only the edited file's package for speed.

`go-ci.sh` runs only when a `go.mod` is present, so it is a no-op outside Go
modules.

## Install

Copy the scripts to your hooks directory and make them executable:

```bash
mkdir -p ~/.claude/hooks
cp go-lint.sh go-ci.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/go-lint.sh ~/.claude/hooks/go-ci.sh
```

Wire them into `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/go-lint.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/go-ci.sh" }
        ]
      }
    ]
  }
}
```

## Requirements

- `go`, `gofmt`, `golangci-lint`, and `jq` on `PATH`.
- `goimports` is optional — the hook skips it gracefully if absent
  (`go install golang.org/x/tools/cmd/goimports@latest`).
- **Version match matters:** `golangci-lint` refuses to run when a project's
  target Go version (in `go.mod`) is newer than the Go toolchain it was built
  with. If you upgrade Go, rebuild it:
  `go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest`.

## Token economy

Hook `stderr` is fed straight into the agent's context, so verbose lint output
is a direct token tax on every edit. The hooks minimise it:

- `--output.text.print-issued-lines=false` — drops the source-snippet + `^`
  caret lines golangci-lint prints under every issue (~60% fewer tokens, zero
  info loss; `file:line:col message` is all the agent needs to fix).
- `--output.text.colors=false` — strips ANSI escapes (pure noise when piped).
- `--max-same-issues=2` — avoids repeating the same finding dozens of times.
- `--new` (per-edit hook only) — reports only issues in the current change, not
  the whole legacy package; keeps pre-existing debt out of context. Requires a
  git repo and a prior commit to diff against. The `Stop` CI gate omits `--new`
  on purpose — it is meant to catch everything.
- Output is hard-capped at 30 lines with a `... +N more lines` summary, so a
  pathological file can't flood the context window.

Note: hooks govern *input* tokens (what the linter feeds back). They cannot make
the agent's *replies* terse — that is a skill/prompt concern (see `token-diet/`).

## Notes

- `--fast-only`'s first run in a package is slower (it warms the type cache);
  later edits are quick.
- Per-edit linting is intentionally package-scoped, not repo-wide — a full
  `./...` run on every edit makes the agent crawl. The repo-wide pass lives in
  the `Stop` hook so it runs once per turn.
