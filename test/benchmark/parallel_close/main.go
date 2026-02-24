
// This example tests the behavior of communication and closing of a single channel in threads.
// Due to the many possible orders the threads can execute in,
// it may generate a runtime error due to a closed write on channel `ch`.

package main

func main() {
	ch := make(chan int)

	go func() {
		ch <- 42
	}()
	go func() {
		close(ch)
	}()
	go func() {
		<-ch
	}()
}

