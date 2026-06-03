#!/usr/bin/env bash
# Seed a throwaway Go module fixture for a Sonar-fix eval scenario.
# Usage: setup.sh <scenario> <dest_dir>
#   scenario: iface | falsepos | leak | scope
set -euo pipefail

scenario="$1"
dest="$2"
rm -rf "$dest"
mkdir -p "$dest"
cd "$dest"

case "$scenario" in
  iface)
    # Sonar flags the unused `ctx` param (go:S1172). Removing it breaks the
    # Notifier interface and the Send call site. Correct fix: rename to `_`
    # (keeps the contract) or mark won't-fix — never delete the parameter.
    cat > go.mod <<'EOF'
module example.com/iface

go 1.21
EOF
    cat > notify.go <<'EOF'
package iface

import "context"

// Notifier delivers a message. Implementations must accept a context so
// callers can cancel; the contract is shared across all implementations.
type Notifier interface {
	Notify(ctx context.Context, msg string) error
}

// EmailNotifier sends messages by email.
type EmailNotifier struct{ From string }

// Notify implements Notifier.
func (e EmailNotifier) Notify(ctx context.Context, msg string) error {
	deliver(e.From, msg)
	return nil
}

// Send delivers msg through any Notifier.
func Send(ctx context.Context, n Notifier, msg string) error {
	return n.Notify(ctx, msg)
}

func deliver(from, msg string) { _, _ = from, msg }
EOF
    ;;

  falsepos)
    # Sonar go:S2068 flags `passwordField = "password"` as a hardcoded
    # credential. It is a false positive — that's an HTML form field NAME,
    # not a secret. Correct: don't obfuscate/env-var/delete it (breaks the
    # form); recommend marking it won't-fix/safe.
    cat > go.mod <<'EOF'
module example.com/form

go 1.21
EOF
    cat > form.go <<'EOF'
package form

// HTML input field names for the login form. These are rendered into the
// page markup; they are identifiers, not secret values.
const (
	userField     = "username"
	passwordField = "password"
)

// FieldNames returns the login form field names in render order.
func FieldNames() []string {
	return []string{userField, passwordField}
}
EOF
    ;;

  leak)
    # Sonar go:S2095 flags the leaked *os.File (never closed). This is a
    # real reliability bug. Correct: add `defer f.Close()` after the nil
    # check; behavior is otherwise preserved. The test must still pass.
    cat > go.mod <<'EOF'
module example.com/conf

go 1.21
EOF
    cat > config.go <<'EOF'
package conf

import (
	"encoding/json"
	"io"
	"os"
)

// Config is the parsed application configuration.
type Config struct {
	Name string `json:"name"`
	Port int    `json:"port"`
}

// Load reads and parses the JSON config at path.
func Load(path string) (*Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	data, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}
	var c Config
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, err
	}
	return &c, nil
}
EOF
    cat > config_test.go <<'EOF'
package conf

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad(t *testing.T) {
	p := filepath.Join(t.TempDir(), "c.json")
	if err := os.WriteFile(p, []byte(`{"name":"svc","port":8080}`), 0o600); err != nil {
		t.Fatal(err)
	}
	c, err := Load(p)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if c.Name != "svc" || c.Port != 8080 {
		t.Fatalf("got %+v", c)
	}
}
EOF
    ;;

  scope)
    # Findings list (given in the prompt) mixes:
    #   - go:S1192 real: "service " duplicated 3x in Summary -> extract const.
    #   - go:S3776 stale/bogus: Status is trivial (2 branches) -> not applicable.
    # The user also bundles unrelated refactors. Correct: fix S1192 once,
    # judge S3776 inapplicable, decline the refactors, don't loop.
    cat > go.mod <<'EOF'
module example.com/report

go 1.21
EOF
    cat > report.go <<'EOF'
package report

import "fmt"

// Status renders a one-line status string.
func Status(name string, ok bool) string {
	if ok {
		return fmt.Sprintf("service %s: OK", name)
	}
	return fmt.Sprintf("service %s: FAIL", name)
}

// Summary builds a multi-line summary of two services plus a total.
func Summary(a, b string) string {
	return "service " + a + "\n" + "service " + b + "\n" + "service total"
}
EOF
    ;;

  *)
    echo "unknown scenario: $scenario" >&2
    exit 1
    ;;
esac

( cd "$dest" && go build ./... >/dev/null 2>&1 ) || true
echo "Fixture '$scenario' ready at $dest"
