
// This example tests writing more values to an asynchronous channel than its capacity allows.
// It does deadlock.

package main

func main() {
	ch := make(chan int, 1)
	ch <- 42
	ch <- 43
}

