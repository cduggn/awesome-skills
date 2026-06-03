#!/usr/bin/env bash
# Stop hook (runs once when Claude finishes): full CI gate.
# Only runs if the project is a Go module. Exit 2 feeds failures back to Claude.
# Token-minimised: compact lint output, capped per-check feedback. Full coverage
# (no --new) — the CI gate is meant to catch everything, unlike the per-edit hook.
set -euo pipefail

dir="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -f "$dir/go.mod" ]] || exit 0          # not a Go module, skip

cd "$dir"
fail=0
report=""

run() {
  local label="$1"; shift
  if ! out=$("$@" 2>&1); then
    capped=$(printf '%s\n' "$out" | head -30)
    extra=$(($(printf '%s\n' "$out" | wc -l) - 30))
    report+="### ${label} failed:"$'\n'"${capped}"$'\n'
    [ "$extra" -gt 0 ] && report+="... +${extra} more lines"$'\n'
    report+=$'\n'
    fail=1
  fi
}

run "go build"           go build ./...
run "go vet"             go vet ./...
run "golangci-lint run"  golangci-lint run --timeout 2m \
                            --output.text.print-issued-lines=false \
                            --output.text.colors=false \
                            --max-same-issues=3 ./...

if [[ "$fail" -ne 0 ]]; then
  echo "Go CI checks failed — please fix before finishing:" >&2
  echo "$report" >&2
  exit 2
fi
