package main

// Goroutine leak due to failure to drain the channel
// daemon/health.go:184
func monitor(stop chan struct{}) {
	results := make(chan struct{})

	go func() {
		results <- struct{}{}
		close(results)
	}()

	select {
	case <-stop:
		// results is not emptied, goroutine leak
		return
	case _ = <-results:
	}
}

func main() {
	stop := make(chan struct{})
	go monitor(stop)
	close(stop)
}
