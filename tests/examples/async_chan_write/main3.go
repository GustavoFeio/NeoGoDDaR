
// This example tests writing to an asynchronous channel without a corresponding read.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 1)
	go func() {
		<-ch
	}()
	ch <- 42
	ch <- 43
}

