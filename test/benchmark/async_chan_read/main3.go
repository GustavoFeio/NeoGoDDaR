
// This example tests reading from an asynchronous channel with a stored value.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 1)
	ch <- 42
	<-ch
}

