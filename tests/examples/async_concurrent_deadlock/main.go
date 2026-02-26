
// This example tests concurrently reading from an asynchronous channel without a corresponding write.
// Since one of the goroutines is not able to execute the read,
// it produces a deadlock.

package main

func main() {
	ch := make(chan int, 1)
	go func() {
		<-ch
	}()
	go func() {
		<-ch
	}()
	ch <- 42
}

