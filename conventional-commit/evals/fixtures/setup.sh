#!/usr/bin/env bash
# Build a throwaway git repo with uncommitted changes for a given scenario.
# Usage: setup.sh <scenario> <dest_dir>
#   scenario: bugfix | mixed | breaking
set -euo pipefail

scenario="$1"
dest="$2"
rm -rf "$dest"
mkdir -p "$dest"
cd "$dest"

git init -q
git config user.email "test@example.com"
git config user.name "Test User"
git config commit.gpgsign false

seed_commit() {
  git add -A
  git commit -q -m "chore: initial commit"
}

case "$scenario" in
  bugfix)
    # Baseline: a cache module with a read-path-only eviction bug.
    cat > cache.py <<'EOF'
class Cache:
    def __init__(self, ttl):
        self.ttl = ttl
        self.store = {}

    def get(self, key):
        entry = self.store.get(key)
        if entry and entry["expires"] > now():
            return entry["value"]
        self.store.pop(key, None)  # evict on read
        return None

    def set(self, key, value):
        self.store[key] = {"value": value, "expires": now() + self.ttl}
EOF
    git add -A && git commit -q -m "feat: add cache"
    # The fix: also evict on write so concurrent updates don't serve stale copies.
    cat > cache.py <<'EOF'
class Cache:
    def __init__(self, ttl):
        self.ttl = ttl
        self.store = {}

    def get(self, key):
        entry = self.store.get(key)
        if entry and entry["expires"] > now():
            return entry["value"]
        self.store.pop(key, None)
        return None

    def set(self, key, value):
        self.store.pop(key, None)  # evict stale copy before overwrite
        self.store[key] = {"value": value, "expires": now() + self.ttl}
EOF
    ;;

  mixed)
    # Baseline repo with code, deps, and docs.
    cat > app.py <<'EOF'
def greet(name):
    return f"Hello, {name}"
EOF
    cat > requirements.txt <<'EOF'
requests==2.28.0
EOF
    cat > README.md <<'EOF'
# Demo App

A tiny demo.
EOF
    seed_commit
    # Three unrelated changes staged together:
    # 1) new feature
    cat >> app.py <<'EOF'

def farewell(name):
    return f"Goodbye, {name}"
EOF
    # 2) dependency bump
    cat > requirements.txt <<'EOF'
requests==2.31.0
EOF
    # 3) docs edit
    cat > README.md <<'EOF'
# Demo App

A tiny demo app with greet and farewell helpers.

## Usage
See app.py.
EOF
    ;;

  breaking)
    # Baseline: an auth API supporting v1 tokens.
    cat > auth.py <<'EOF'
def authenticate(token):
    """Accepts v1 bearer tokens and v2 tokens."""
    if token.startswith("v1_"):
        return verify_v1(token)
    if token.startswith("v2_"):
        return verify_v2(token)
    raise ValueError("unknown token")
EOF
    git add -A && git commit -q -m "feat(api): add authentication"
    # Breaking change: drop v1 support entirely.
    cat > auth.py <<'EOF'
def authenticate(token):
    """Accepts v2 tokens only. v1 support removed."""
    if token.startswith("v2_"):
        return verify_v2(token)
    raise ValueError("v1 tokens are no longer supported; re-authenticate for v2")
EOF
    ;;

  *)
    echo "unknown scenario: $scenario" >&2
    exit 1
    ;;
esac

echo "Fixture '$scenario' ready at $dest"
git -C "$dest" status --short
