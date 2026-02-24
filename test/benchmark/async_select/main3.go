
// This examples tests both input and output cases of a select statement with asynchronous channels.
// It does not deadlock.

package main

func main() {
	ch := make(chan int, 1)
	select {
	case ch <- 42:
	case <-ch:
	}
}

