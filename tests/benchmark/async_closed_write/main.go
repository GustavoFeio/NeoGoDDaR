
// This example tests writing to a closed asynchronous channel after values had already been written.
// It generates a runtime error due to a closed write on channel `ch`.

package main

func main() {
	ch := make(chan int, 10)
	ch <- 42
	ch <- 43
	close(ch)
	ch <- 44
}

