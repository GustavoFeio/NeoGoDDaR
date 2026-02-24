
// This example tests basic channel closing operations.
// It does not deadlock.

package main

func foo(ch chan int) {
	close(ch)
}

func main() {
	ch := make(chan int)
	ch1 := make(chan int)
	foo(ch1)
	close(ch)
}

