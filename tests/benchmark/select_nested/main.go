
// This example tests the behavior of nested select statements.
// Since there are no actions outside the select to synchronize with its statements,
// is does deadlock.

package main

func main() {
	ch := make(chan int)
	select {
	case <-ch:
		select {
		case <-ch:
		case ch <- 42:
		}
	case ch <- 43:
	}
}

