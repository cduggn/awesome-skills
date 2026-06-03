#!/usr/bin/env bash
# PostToolUse (per-edit): format the edited Go file, then fast-lint its package.
# Token-minimised: no source snippets, no colors, only NEW issues, capped output.
# Exit 0 = silent pass; exit 2 = stderr fed back to Claude to auto-fix.
set -euo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.go ]] || exit 0          # only Go files
[[ -f "$file" ]] || exit 0

# 1. Fast auto-fixers (mutate file in place, silent)
gofmt -w "$file"
command -v goimports >/dev/null 2>&1 && goimports -w "$file"

# 2. Lint only the changed file's package, only new issues, compact output
dir=$(dirname "$file")
if ! out=$(golangci-lint run --fast-only --timeout 30s \
      --output.text.print-issued-lines=false \
      --output.text.colors=false \
      --max-same-issues=2 \
      --new \
      "$dir" 2>&1); then
  {
    echo "golangci-lint issues in $dir (fix these first):"
    echo "$out" | head -30
    extra=$(($(printf '%s\n' "$out" | wc -l) - 30))
    [ "$extra" -gt 0 ] && echo "... +$extra more lines — rerun lint after fixing the above"
  } >&2
  exit 2
fi
