
// This example tests concurrently closing an asynchronous channel twice.
// It generates a runtime error due to a double close on channel `ch`.

package main

func main() {
	ch := make(chan int, 10)
	go func() {
		ch <- 42
		close(ch)
	}()
	<-ch
	close(ch)
}

