
// This example tests a writing branch of a select statement with asynchronous channels.
// It does not deadlock.

package main

func tau() {
	
}

func main() {
	ch := make(chan int, 1)
	select {
	case ch <- 1:
	default:
		// needed to force migoinfer to generate the select
		tau()
	}
}

