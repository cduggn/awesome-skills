package hang

import "testing"

// TestHang never returns: it reads from a channel that nothing ever sends to.
// Without an explicit -timeout, `go test` waits the full default (10m) before
// killing it. The fixer must bound the run with -timeout and report the hang.
func TestHang(t *testing.T) {
	ch := make(chan int) // unbuffered, no sender, never closed
	got := Drain(ch)     // blocks forever here
	if got != 1 {
		t.Fatalf("Drain() = %d, want 1", got)
	}
}
