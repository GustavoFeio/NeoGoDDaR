
// This example tries to read twice from a channel that is only written to once.
// It does deadlock.

package main

func main() {
	ch := make(chan int)
	go func() {
		ch <- 1
	}()
	<-ch
	<-ch
}

