
// This example tests the behavior of the default case of a select statement.
// It does not deadlock.

package main

func main() {
	ch := make(chan int)
	select {
	case <-ch:
	case ch <- 42:
	default:
	}
}

