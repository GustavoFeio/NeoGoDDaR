
// This example tests writing n+1 values into an asynchronous channel with capacity n,
// with a read in between.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 5)
	ch <- 42
	ch <- 43
	<-ch
	ch <- 44
	ch <- 45
	ch <- 46
	ch <- 47
}

