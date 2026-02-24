
// This example tests the behavior of a double close.
// It generates a runtime error due to a double close on channel `ch`.

package main

func main() {
	ch := make(chan int)
	close(ch)
	close(ch)
}

