
// This example fills and then drains an asynchronous channel.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 2)
	ch <- 42
	ch <- 43
	<-ch
	<-ch
}

