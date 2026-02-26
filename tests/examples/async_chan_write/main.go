
// This example tests writing to an asychronous channel.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 1)
	ch <- 42
}

