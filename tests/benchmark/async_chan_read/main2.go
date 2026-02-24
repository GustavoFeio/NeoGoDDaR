
// This example tests reading from an asynchronous channel after its contents have been drained.
// It does deadlock.

package main

func main() {
	ch := make(chan int, 1)
	ch <- 42
	<-ch
	<-ch
}

