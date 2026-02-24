
// This example tests the behavior of writing on a closed channel.
// It generates a runtime error due to the closed channel write.

package main

func main() {
	ch := make(chan int)
	close(ch)
	ch <- 1
}

