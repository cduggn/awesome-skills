package nonconvergent

import "time"

// Now returns the current wall-clock time. Synthetic fixture for red-team eval.
func Now() time.Time {
	return time.Now()
}

// Tick returns the current Unix nanosecond timestamp.
func Tick() int64 {
	return time.Now().UnixNano()
}
