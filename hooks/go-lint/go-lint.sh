#!/usr/bin/env bash
# PostToolUse (per-edit): format the edited Go file, then fast-lint its package.
# Exit 0 = silent pass; exit 2 = stderr fed back to Claude to auto-fix.
set -euo pipefail

file=$(jq -r '.tool_input.file_path // empty')
[[ "$file" == *.go ]] || exit 0          # only Go files
[[ -f "$file" ]] || exit 0

# 1. Fast auto-fixers (mutate file in place, silent)
gofmt -w "$file"
command -v goimports >/dev/null 2>&1 && goimports -w "$file"

# 2. Lint only the edited file's package (scoped for speed)
dir=$(dirname "$file")
if ! out=$(golangci-lint run --fast-only --timeout 30s "$dir" 2>&1); then
  {
    echo "golangci-lint reported issues in $dir — please fix:"
    echo "$out"
  } >&2
  exit 2
fi
