
// This example tests the behavior of reading from a channel with capacity greater than 0.
// It does deadlock.

package main

func main() {
	ch := make(chan int, 1)
	<-ch
}

