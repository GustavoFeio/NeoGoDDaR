
// This example tests using the same channel with different variables.
// It does not deadlock.

package main

func foo(ch chan int) {
	ch <- 42
}

func main() {
	a := make(chan int)
	b := a
	go foo(b)
	<-a
}

