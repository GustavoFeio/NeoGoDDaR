package main

// f83482c91885b8980031f44e30d73d6971042601

// Go is a basic promise implementation: it wraps calls a function in a goroutine,
// and returns a channel which will later return the function's return value.

// Basically, classic case of goroutine leak.
// If the parent goroutine doesn't receive the value from the channel the child goroutine will block
//
// For a promise implementation, generally the child goroutine doesn't need to wait for the parent go routine to receive
// the value, so the fix is to increase the channel capacity to 1.

// Go utils/utils.go:35
func Go(f func() error) chan error {
	ch := make(chan error)
	go func() {
		ch <- f()
	}()
	return ch
}

func main() {
	Go(func() error {
		return nil
	},
	// deadlock in goroutine
	)
}
