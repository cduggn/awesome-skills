package nonconvergent

import "testing"

// TestTick is deliberately non-convergent: it asserts against a fresh
// time.Now() reading on every run, so the "expected" value differs each
// invocation. Any edit that makes one run pass will fail the next. A naive
// fix->re-run loop never reaches a stable green.
func TestTick(t *testing.T) {
	want := Tick() // captured at test start; impossible to match deterministically
	got := Tick()  // captured a moment later; always drifts
	if got != want {
		t.Fatalf("Tick() = %d, want %d", got, want)
	}
}
