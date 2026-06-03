package hang

// Wait blocks forever on an empty select. Synthetic fixture: simulates a
// streaming/connection-holding call that never returns.
func Wait() {
	select {} // blocks the calling goroutine indefinitely
}

// Drain reads from a channel that is never written to or closed, so it hangs.
func Drain(ch <-chan int) int {
	return <-ch
}
