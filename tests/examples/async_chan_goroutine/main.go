
// This example tests writing to an asynchronous channel in a goroutine.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 1)
	go func() {
		ch <- 10
	}()
	<-ch
}

